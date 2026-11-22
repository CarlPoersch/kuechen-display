import SwiftUI
import Combine
import AudioToolbox
import UserNotifications

// ============================================================
// Timer: mehrere gleichzeitig, mit Namen ("Reis", "Schritt 3").
// Läuft ein Timer ab, klingelt Hubert und zeigt einen großen Hinweis –
// über allem, egal wo man gerade ist. Ist die App im Hintergrund,
// kommt eine Mitteilung.
// ============================================================

struct KitchenTimer: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var total: TimeInterval
    var end: Date
    var pausedLeft: TimeInterval?   // gesetzt = pausiert
    var source: String? = nil       // Rezept, aus dem der Timer kommt
    var icon: String? = nil         // dessen Emoji

    var left: TimeInterval { pausedLeft ?? max(0, end.timeIntervalSinceNow) }
    var progress: Double { total > 0 ? 1 - left / total : 1 }
}

final class TimerCenter: ObservableObject {
    static let shared = TimerCenter()
    /// Haushalt für den Live-Abgleich (nil = nur auf diesem Gerät)
    var household: String?
    /// Hier mit „OK“ beendet – nicht durch einen älteren Abgleich wieder klingeln lassen
    private var dismissedIds: [UUID: Date] = [:]
    @Published private(set) var timers: [KitchenTimer] = []
    @Published private(set) var ringing: [KitchenTimer] = []
    @Published private(set) var tick = Date()
    private var clock: AnyCancellable?
    private var lastBeep = Date.distantPast

    /// Zuletzt verwendete Timer (wie in der Uhr-App) – pro Gerät gemerkt
    struct Recent: Codable, Hashable, Identifiable {
        var name: String; var secs: Int
        var id: String { name + "|\(secs)" }
    }
    @Published private(set) var recents: [Recent] = {
        guard let d = UserDefaults.standard.data(forKey: "timer.recents"),
              let r = try? JSONDecoder().decode([Recent].self, from: d) else { return [] }
        return r
    }()

    func start(_ name: String, minutes: Double, source: String? = nil, icon: String? = nil) {
        start(name, seconds: Int(minutes * 60), source: source, icon: icon)
    }

    func start(_ name: String, seconds: Int, source: String? = nil, icon: String? = nil) {
        let secs = TimeInterval(max(5, seconds))
        let t = KitchenTimer(name: name, total: secs, end: Date().addingTimeInterval(secs), source: source, icon: icon)
        timers.append(t)
        if source == nil { remember(Recent(name: name, secs: Int(secs))) }
        notify(t)
        push(t)
        run()
    }

    /// Name und Restzeit ändern (Restzeit neu = Ring beginnt von vorn)
    func edit(_ t: KitchenTimer, name: String, left: Int) {
        guard let i = timers.firstIndex(where: { $0.id == t.id }) else { return }
        timers[i].name = name
        let secs = TimeInterval(max(5, left))
        if abs(secs - timers[i].left) >= 1 {
            timers[i].total = secs
            if timers[i].pausedLeft != nil { timers[i].pausedLeft = secs } else { timers[i].end = Date().addingTimeInterval(secs) }
        }
        if timers[i].pausedLeft == nil { notify(timers[i]) }
        push(timers[i])
    }

    func restart(_ t: KitchenTimer) {
        guard let i = timers.firstIndex(where: { $0.id == t.id }) else { return }
        timers[i].pausedLeft = nil
        timers[i].end = Date().addingTimeInterval(timers[i].total)
        notify(timers[i])
        push(timers[i])
    }

    func forget(_ r: Recent) {
        recents.removeAll { $0 == r }; saveRecents()
    }

    private func remember(_ r: Recent) {
        recents.removeAll { $0 == r }
        recents.insert(r, at: 0)
        recents = Array(recents.prefix(8))
        saveRecents()
    }

    private func saveRecents() {
        if let d = try? JSONEncoder().encode(recents) { UserDefaults.standard.set(d, forKey: "timer.recents") }
    }

    func cancel(_ t: KitchenTimer) {
        timers.removeAll { $0.id == t.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [t.id.uuidString])
        dismissedIds[t.id] = Date()
        removeRemote(t.id)
    }

    func pause(_ t: KitchenTimer) {
        guard let i = timers.firstIndex(where: { $0.id == t.id }) else { return }
        if let left = timers[i].pausedLeft {
            timers[i].end = Date().addingTimeInterval(left); timers[i].pausedLeft = nil; notify(timers[i])
        } else {
            timers[i].pausedLeft = timers[i].left
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [t.id.uuidString])
        }
        push(timers[i])
    }

    func add(_ t: KitchenTimer, minutes: Double) {
        guard let i = timers.firstIndex(where: { $0.id == t.id }) else { return }
        if timers[i].pausedLeft != nil { timers[i].pausedLeft! += minutes * 60 } else { timers[i].end.addTimeInterval(minutes * 60) }
        timers[i].total += minutes * 60
        if timers[i].pausedLeft == nil { notify(timers[i]) }
        push(timers[i])
    }

    /// Klingeln beenden (optional: noch 1 Minute)
    func dismiss(_ t: KitchenTimer, snooze: Bool = false) {
        ringing.removeAll { $0.id == t.id }
        dismissedIds[t.id] = Date()
        removeRemote(t.id)   // „OK“ auf einem Gerät beendet das Klingeln überall
        if snooze { start(t.name, seconds: 60, source: t.source, icon: t.icon) }
    }

    // MARK: Live-Abgleich im Haushalt

    private func push(_ t: KitchenTimer) {
        guard let h = household else { return }
        let row = LiveTimerRow(t, household: h)
        Task { try? await SupabaseClient.shared.upsert("kitchen_timers", [row]) }
    }

    /// Beenden auf allen Geräten: als erledigt markieren (UPDATE kommt per Realtime sicher an, DELETE nicht)
    private func removeRemote(_ id: UUID) {
        guard household != nil else { return }
        struct Done: Encodable { let done_at: String }
        Task { try? await SupabaseClient.shared.update("kitchen_timers", ["id": "eq." + id.uuidString.lowercased()], Done(done_at: ISO.string(Date()))) }
    }

    private func purge(_ id: UUID) {
        Task { try? await SupabaseClient.shared.delete("kitchen_timers", ["id": "eq." + id.uuidString.lowercased()]) }
    }

    /// Stand vom Server übernehmen: neue Timer dazu, geänderte anpassen, anderswo beendete entfernen.
    /// Abgelaufene klingeln auf jedem Gerät, bis irgendwo „OK“ gedrückt wird.
    func apply(remote rows: [LiveTimerRow]) {
        let now = Date()
        dismissedIds = dismissedIds.filter { now.timeIntervalSince($0.value) < 120 }
        var next: [KitchenTimer] = []
        var ring = ringing
        var seen = Set<UUID>()
        for r in rows {
            // Beendete Einträge: ignorieren, nach 10 Minuten ganz löschen (aufräumen)
            if let d = r.done_at.flatMap(ISO.date) {
                if now.timeIntervalSince(d) > 600, let u = UUID(uuidString: r.id) { purge(u) }
                continue
            }
            guard let t = r.timer, dismissedIds[t.id] == nil else { continue }
            seen.insert(t.id)
            if t.pausedLeft == nil && t.end <= now {
                if now.timeIntervalSince(t.end) > 3 * 3600 { purge(t.id); continue }   // vergessen, aufräumen
                if !ring.contains(where: { $0.id == t.id }) { ring.append(t) }
            } else {
                if timers.first(where: { $0.id == t.id }) != t { notify(t) }
                next.append(t)
            }
        }
        // Gerade hier gestartete Timer, die der Server noch nicht kennt, behalten
        for t in timers where !seen.contains(t.id) && now.timeIntervalSince(t.end.addingTimeInterval(-t.total)) < 10 && t.pausedLeft == nil {
            next.append(t)
        }
        let gone = timers.filter { t in !next.contains { $0.id == t.id } && !ring.contains { $0.id == t.id } }
        if !gone.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: gone.map { $0.id.uuidString })
        }
        ring.removeAll { r in !seen.contains(r.id) }   // anderswo mit „OK“ beendet
        if next != timers { timers = next }
        if ring != ringing { ringing = ring }
        if !timers.isEmpty || !ringing.isEmpty { run() }
    }

    private func run() {
        guard clock == nil else { return }
        clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] now in
            Task { @MainActor in self?.step(now) }
        }
    }

    private func step(_ now: Date) {
        tick = now
        let done = timers.filter { $0.pausedLeft == nil && $0.end <= now }
        if !done.isEmpty {
            timers.removeAll { t in done.contains { $0.id == t.id } }
            ringing += done
        }
        // Klingeln alle 2 s, bis jemand "OK" drückt
        if !ringing.isEmpty, now.timeIntervalSince(lastBeep) >= 2 {
            lastBeep = now
            AudioServicesPlayAlertSound(1005)
        }
        if timers.isEmpty && ringing.isEmpty { clock?.cancel(); clock = nil }
    }

    /// Mitteilung, falls die App gerade nicht offen ist
    private func notify(_ t: KitchenTimer) {
        let c = UNUserNotificationCenter.current()
        Task { _ = try? await c.requestAuthorization(options: [.alert, .sound]) }   // async statt Rückruf (Hintergrund-Thread)
        c.removePendingNotificationRequests(withIdentifiers: [t.id.uuidString])
        guard t.pausedLeft == nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "⏰ " + t.name
        content.body = "Timer ist abgelaufen."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, t.end.timeIntervalSinceNow), repeats: false)
        c.add(UNNotificationRequest(identifier: t.id.uuidString, content: content, trigger: trigger))
    }

    static func format(_ secs: TimeInterval) -> String {
        let s = Int(secs.rounded(.up))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: Ansichten

/// Großer Hinweis, wenn ein Timer abgelaufen ist (liegt über der ganzen App)
struct TimerAlarmOverlay: View {
    @ObservedObject private var center = TimerCenter.shared

    var body: some View {
        if let t = center.ringing.first {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 18) {
                    Image(systemName: "bell.badge.fill").font(.system(size: 54)).foregroundColor(Theme.accent)
                        .symbolRenderingMode(.hierarchical)
                    Text(t.name).font(.system(size: 30, weight: .bold)).multilineTextAlignment(.center)
                    Text("Timer abgelaufen").font(.title3).foregroundColor(Theme.secondary)
                    HStack(spacing: 12) {
                        Button { center.dismiss(t, snooze: true) } label: {
                            Text("+1 Min.").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                        }
                        Button { center.dismiss(t) } label: {
                            Text("OK").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(28)
                .frame(maxWidth: 380)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.card))
                .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
                .padding(24)
            }
            .transition(.opacity)
        }
    }
}

/// Fortschrittsring (läuft im Uhrzeigersinn leer – wie in der Uhr-App)
struct TimerRing: View {
    let timer: KitchenTimer
    var line: CGFloat = 4
    var color: Color = Theme.accent
    // Warum: Der Timer selbst ändert sich beim Ablaufen nicht (nur die Uhr läuft weiter).
    // SwiftUI zeichnet den Ring dann nicht neu – erst der Sekundentakt hier hält ihn in Bewegung.
    @ObservedObject private var center = TimerCenter.shared

    var body: some View {
        let progress = center.tick > .distantPast ? timer.progress : 0
        ZStack {
            Circle().stroke(Color(UIColor.tertiarySystemFill), lineWidth: line)
            Circle().trim(from: 0, to: max(0.001, 1 - progress))
                .stroke(timer.pausedLeft == nil ? color : Color.gray, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}

/// Kompakte Zeile im Kochmodus: Ring, Name, Zeit, Pause, Stopp
struct TimerRow: View {
    let timer: KitchenTimer
    var compact = true
    @ObservedObject private var center = TimerCenter.shared

    var body: some View {
        HStack(spacing: 12) {
            TimerRing(timer: timer, line: 3.5).frame(width: 26, height: 26)
            Text(timer.name).font(.subheadline).lineLimit(1)
            Spacer(minLength: 4)
            Text(TimerCenter.format(timer.left)).font(Font.headline.monospacedDigit().weight(.semibold))
                .foregroundColor(timer.left < 60 ? Theme.accent : .primary)
            CircleButton(symbol: timer.pausedLeft == nil ? "pause.fill" : "play.fill", label: timer.pausedLeft == nil ? "Pausieren" : "Fortsetzen") { center.pause(timer) }
            CircleButton(symbol: "xmark", label: "Timer stoppen", tint: .red) { center.cancel(timer) }
        }
    }
}

/// Runder Knopf mit Symbol
struct CircleButton: View {
    let symbol: String
    let label: String
    var tint: Color = .primary
    var size: CGFloat = 32
    var filled: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(filled == nil ? tint : .white)
                .frame(width: size, height: size)
                .background(Circle().fill(filled ?? (tint == .red ? Color.red.opacity(0.12) : Color(UIColor.tertiarySystemFill))))
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}

/// Laufender Timer als große Zeile: Ring mit Zeit, Name, Herkunft, Knöpfe. Antippen = bearbeiten.
struct TimerCard: View {
    let timer: KitchenTimer
    let onEdit: () -> Void
    @ObservedObject private var center = TimerCenter.shared

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                TimerRing(timer: timer, line: 5)
                if let i = timer.icon { Text(i).font(.system(size: 22)) }
                else { Image(systemName: "timer").font(.title3).foregroundColor(Theme.accent) }
            }
            .frame(width: 56, height: 56)
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimerCenter.format(timer.left))
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundColor(timer.pausedLeft != nil ? Theme.secondary : timer.left < 60 ? Theme.accent : .primary)
                    HStack(spacing: 6) {
                        Text(timer.name).font(.subheadline).foregroundColor(.primary).lineLimit(1)
                        if timer.source != nil {
                            Label("Küche", systemImage: "fork.knife").font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.accent.opacity(0.14))).foregroundColor(Theme.accent)
                        }
                        if timer.pausedLeft != nil { Text("Pausiert").font(.caption).foregroundColor(Theme.secondary) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(timer.name), noch \(TimerCenter.format(timer.left)). Bearbeiten")
            CircleButton(symbol: "plus", label: "Eine Minute mehr", size: 40) { center.add(timer, minutes: 1) }
            CircleButton(symbol: timer.pausedLeft == nil ? "pause.fill" : "play.fill",
                         label: timer.pausedLeft == nil ? "Pausieren" : "Fortsetzen", size: 44,
                         filled: timer.pausedLeft == nil ? .orange : .green) { center.pause(timer) }
            CircleButton(symbol: "xmark", label: "Stoppen", tint: .red, size: 40) { withAnimation { center.cancel(timer) } }
        }
        .padding(.vertical, 6)
    }
}

/// Das Drehrad aus der Uhr-App: Stunden, Minuten, Sekunden.
/// Warum UIKit: Drei SwiftUI-Räder nebeneinander überlappen sich auf iOS 15 beim Antippen.
struct DurationWheel: UIViewRepresentable {
    @Binding var seconds: Int

    func makeUIView(context: Context) -> UIPickerView {
        let p = UIPickerView()
        p.dataSource = context.coordinator
        p.delegate = context.coordinator
        p.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        select(p, animated: false)
        return p
    }

    func updateUIView(_ p: UIPickerView, context: Context) {
        context.coordinator.parent = self
        let cur = p.selectedRow(inComponent: 0) * 3600 + p.selectedRow(inComponent: 1) * 60 + p.selectedRow(inComponent: 2)
        if cur != seconds { select(p, animated: true) }
    }

    private func select(_ p: UIPickerView, animated: Bool) {
        p.selectRow(min(23, seconds / 3600), inComponent: 0, animated: animated)
        p.selectRow(seconds / 60 % 60, inComponent: 1, animated: animated)
        p.selectRow(seconds % 60, inComponent: 2, animated: animated)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: DurationWheel
        init(_ p: DurationWheel) { parent = p }
        private let units = ["Std.", "Min.", "Sek."]

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent c: Int) -> Int { c == 0 ? 24 : 60 }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent c: Int) -> CGFloat { 40 }
        func pickerView(_ pickerView: UIPickerView, widthForComponent c: Int) -> CGFloat {
            max(70, min(130, (pickerView.bounds.width - 20) / 3))
        }
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent c: Int, reusing view: UIView?) -> UIView {
            let l = (view as? UILabel) ?? UILabel()
            let text = NSMutableAttributedString(string: "\(row)", attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 23, weight: .regular)])
            text.append(NSAttributedString(string: "  " + units[c], attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .semibold)]))
            l.attributedText = text
            l.textAlignment = .center
            return l
        }
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent c: Int) {
            parent.seconds = pickerView.selectedRow(inComponent: 0) * 3600 + pickerView.selectedRow(inComponent: 1) * 60
                + pickerView.selectedRow(inComponent: 2)
        }
    }
}

/// App „Timer“ im Stil der Uhr-App: Rad drehen, Name, Start. Darunter laufende Timer
/// (auch die aus der Küche), zuletzt verwendete und Schnellstart.
struct TimerToolView: View {
    @ObservedObject private var center = TimerCenter.shared
    @State private var seconds = 10 * 60
    @State private var name = ""
    @State private var editing: KitchenTimer?
    private let presets = [1, 3, 5, 8, 10, 15, 20, 30, 45, 60]

    var body: some View {
        List {
            // Neuer Timer
            Section {
                DurationWheel(seconds: $seconds)
                    .frame(height: 200)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                HStack {
                    Text("Bezeichnung")
                    TextField("Timer", text: $name).multilineTextAlignment(.trailing).submitLabel(.done)
                }
                HStack {
                    Button("Zurücksetzen") { withAnimation { seconds = 0; name = "" } }
                        .buttonStyle(.borderless).foregroundColor(Theme.secondary)
                        .disabled(seconds == 0 && name.isEmpty)
                    Spacer()
                    Button { startNew() } label: {
                        Label("Starten", systemImage: "play.fill").font(.headline).foregroundColor(.white)
                            .padding(.horizontal, 26).frame(height: 48)
                            .background(Capsule().fill(seconds >= 5 ? Color.green : Color.gray.opacity(0.5)))
                    }
                    .buttonStyle(.borderless)
                    .disabled(seconds < 5)
                }
                .padding(.vertical, 4)
            } header: { Text("Neuer Timer") }

            // Schnellstart: setzt das Rad (zweimal tippen = sofort starten wäre versteckt – lieber sichtbar)
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { m in
                            Button { withAnimation { seconds = m * 60 } } label: {
                                Text(m == 60 ? "1 Std." : "\(m) Min.").font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .foregroundColor(seconds == m * 60 ? .white : Theme.accent)
                                    .background(Capsule().fill(seconds == m * 60 ? Theme.accent : Theme.accent.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if !center.timers.isEmpty {
                Section {
                    ForEach(center.timers.sorted { $0.left < $1.left }) { t in
                        TimerCard(timer: t) { editing = t }
                    }
                } header: { Text("Läuft") } footer: {
                    Text("Antippen zum Bearbeiten. Timer aus dem Kochmodus stehen hier mit „Küche“.")
                }
            }

            if !center.recents.isEmpty {
                Section("Zuletzt verwendet") {
                    ForEach(center.recents) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(TimerCenter.format(TimeInterval(r.secs))).font(.system(size: 30, weight: .light).monospacedDigit())
                                Text(r.name).font(.subheadline).foregroundColor(Theme.secondary)
                            }
                            Spacer()
                            CircleButton(symbol: "play.fill", label: "\(r.name) starten", size: 44, filled: .green) {
                                withAnimation { center.start(r.name, seconds: r.secs) }
                            }
                        }
                        .swipeActions { Button(role: .destructive) { center.forget(r) } label: { Label("Entfernen", systemImage: "trash") } }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editing) { TimerEditSheet(timer: $0) }
    }

    private func startNew() {
        let n = name.trimmingCharacters(in: .whitespaces)
        withAnimation { center.start(n.isEmpty ? "Timer" : n, seconds: seconds) }
        name = ""
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Laufenden Timer bearbeiten: Name, Restzeit am Rad, neu starten, stoppen
struct TimerEditSheet: View {
    let timer: KitchenTimer
    @ObservedObject private var center = TimerCenter.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var seconds: Int

    init(timer: KitchenTimer) {
        self.timer = timer
        _name = State(initialValue: timer.name)
        _seconds = State(initialValue: Int(timer.left.rounded()))
    }

    private var live: KitchenTimer? { center.timers.first { $0.id == timer.id } }

    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("Bezeichnung", text: $name)
                    if let s = timer.source {
                        Label("Aus dem Rezept „\(s)“", systemImage: "fork.knife").font(.subheadline).foregroundColor(Theme.secondary)
                    }
                }
                Section {
                    DurationWheel(seconds: $seconds).frame(height: 200).frame(maxWidth: .infinity)
                } header: { Text("Restzeit") } footer: {
                    if let l = live { Text("Läuft gerade: noch \(TimerCenter.format(l.left))") }
                }
                Section {
                    Button { if let l = live { center.restart(l) }; dismiss() } label: {
                        Label("Von vorn (\(TimerCenter.format(timer.total)))", systemImage: "arrow.counterclockwise")
                    }
                    Button { if let l = live { center.pause(l) } } label: {
                        Label(live?.pausedLeft == nil ? "Pausieren" : "Fortsetzen", systemImage: live?.pausedLeft == nil ? "pause.fill" : "play.fill")
                    }
                    Button(role: .destructive) { if let l = live { center.cancel(l) }; dismiss() } label: {
                        Label("Timer stoppen", systemImage: "xmark.circle")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timer bearbeiten").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if let l = live { center.edit(l, name: name.trimmingCharacters(in: .whitespaces).isEmpty ? l.name : name, left: seconds) }
                        dismiss()
                    }
                    .disabled(seconds < 5)
                }
            }
            .onChange(of: center.timers.count) { _ in if live == nil { dismiss() } }
        }
        .navigationViewStyle(.stack)
    }
}
