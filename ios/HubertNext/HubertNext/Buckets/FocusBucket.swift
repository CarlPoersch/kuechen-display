import SwiftUI
import Combine
import AudioToolbox
import UserNotifications

// ============================================================
// Fokus: Pomodoro-Timer als App mit Widget.
//  - 25 min Fokus / 5 min Pause, nach 4 Runden 15 min (oder 50/10, 90/15)
//  - Aufgabe benennen, optional mit einem Countdown (z. B. Prüfung) verknüpfen → Minuten zählen dort mit
//  - Statistik: heute, Serie, Woche, pro Aufgabe
//  - Läuft auf allen eigenen Geräten: Kapsel unten, pausieren/beenden von überall
// Abgleich: Tabelle user_focus (eine Zeile je Konto, Realtime). Fehlt sie, läuft der Fokus nur lokal.
// Einstellungen (Bucket): preset = "25/5/15" | "50/10/20" | "90/15/30"
// ============================================================

enum FocusBucket {
    static let kind = BucketKind(
        id: "fokus", name: "Fokus", symbol: "brain.head.profile", tint: .mint, art: .glance,
        interests: ["lernen", "organisation"], blurb: "Pomodoro-Timer mit Aufgaben, Statistik und Prüfungs-Countdowns – auf allen Geräten.",
        defaultConfig: ["preset": .string("25/5/15")],
        glance: { inst, _ in AnyView(FocusGlance(instance: inst)) },
        detail: { inst in AnyView(FocusApp(bucketId: inst.id)) },
        itemLinks: true
    )

    static let presets: [(id: String, label: String)] = [("25/5/15", "25 / 5"), ("50/10/20", "50 / 10"), ("90/15/30", "90 / 15")]
    /// (Fokus, kurze Pause, lange Pause) in Minuten
    static func durations(_ c: [String: JSON]) -> (Int, Int, Int) {
        let p = (c["preset"]?.string ?? "25/5/15").split(separator: "/").compactMap { Int($0) }
        return p.count == 3 ? (p[0], p[1], p[2]) : (25, 5, 15)
    }
}

// MARK: Zustand
// Hinweis: nicht „FocusState“ nennen – so heißt schon der SwiftUI-Baustein @FocusState für Eingabefelder.

struct FocusLog: Codable, Equatable, Identifiable {
    var id: String            // Sitzung + Runde (gleich auf allen Geräten → keine Doppelten)
    var day: String           // yyyy-MM-dd
    var minutes: Int
    var task: String
    var countdown: String?
}

struct FocusSnapshot: Codable, Equatable {
    var active = false        // Sitzung läuft (auch während Pause oder Warten auf die nächste Runde)
    var phase = "focus"       // focus, short, long
    var round = 1
    var rounds = 4
    var end: Date?            // läuft bis …
    var pausedLeft: Double?   // pausiert mit Rest (Sekunden)
    var total: Double = 1500  // Länge der aktuellen Phase
    var task = ""
    var countdown: String?    // verknüpfter Countdown (id)
    var countdownTitle: String?
    var session = ""
    var focusMin = 25, shortMin = 5, longMin = 15
    var log: [FocusLog] = []
    var updated = Date.distantPast

    var isFocus: Bool { phase == "focus" }
    var phaseName: String { phase == "focus" ? "Fokus" : phase == "long" ? "Lange Pause" : "Kurze Pause" }

    static let dayKey: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    static func day(_ d: Date) -> String { dayKey.string(from: d) }

    func minutes(on day: String) -> Int { log.filter { $0.day == day }.reduce(0) { $0 + $1.minutes } }
    func minutes(countdown id: String) -> Int { log.filter { $0.countdown == id }.reduce(0) { $0 + $1.minutes } }
    var today: Int { minutes(on: Self.day(Date())) }

    /// Tage am Stück mit Fokus (heute zählt mit, wenn schon fokussiert)
    var streak: Int {
        let cal = Calendar.current
        var d = cal.startOfDay(for: Date())
        if minutes(on: Self.day(d)) == 0 { d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
        var n = 0
        while minutes(on: Self.day(d)) > 0 { n += 1; d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
        return n
    }
    /// Letzte 7 Tage (älteste zuerst)
    var week: [(day: Date, minutes: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { i in
            let d = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: Date())) ?? Date()
            return (day: d, minutes: minutes(on: Self.day(d)))
        }
    }
    /// Diese Woche (7 Tage) nach Aufgabe
    var byTask: [(task: String, minutes: Int)] {
        let from = Self.day(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        var m: [String: Int] = [:]
        for l in log where l.day >= from { m[l.task.isEmpty ? "Ohne Aufgabe" : l.task, default: 0] += l.minutes }
        return m.map { (task: $0.key, minutes: $0.value) }.sorted { $0.minutes > $1.minutes }
    }
    /// Zuletzt genutzte Aufgaben
    var recentTasks: [String] {
        var out: [String] = []
        for l in log.reversed() where !l.task.isEmpty && !out.contains(l.task) { out.append(l.task); if out.count == 6 { break } }
        return out
    }
}

/// Zeile in der Tabelle user_focus
struct FocusRow: Codable { let user_id: String; let state: FocusSnapshot; let updated_at: String }

final class FocusCenter: ObservableObject {
    static let shared = FocusCenter()
    @Published private(set) var state: FocusSnapshot
    @Published private(set) var tick = Date()
    private var clock: AnyCancellable?
    private let key = "fokus.state.v1"
    private var remoteMissing = false      // Tabelle (noch) nicht da → nur lokal
    /// Tabelle erreichbar → Live-Abgleich darf sie abonnieren (sonst würde der ganze Kanal scheitern)
    private(set) var remoteReady = false

    init() {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(FocusSnapshot.self, from: d) { state = s }
        else { state = FocusSnapshot() }
        run()
    }

    // MARK: Abfragen
    var running: Bool { state.active && state.end != nil }
    var paused: Bool { state.active && state.pausedLeft != nil }
    var waiting: Bool { state.active && state.end == nil && state.pausedLeft == nil }
    var left: TimeInterval {
        if let p = state.pausedLeft { return p }
        if let e = state.end { return max(0, e.timeIntervalSince(tick)) }
        return state.total
    }
    var progress: Double { state.total > 0 ? min(1, max(0, 1 - left / state.total)) : 0 }
    static func clock(_ s: TimeInterval) -> String {
        let v = Int(s.rounded(.up)); return String(format: "%d:%02d", v / 60, v % 60)
    }

    // MARK: Aktionen

    func start(task: String, countdown: CountdownBucket.Entry?, config: [String: JSON]) {
        let (f, s, l) = FocusBucket.durations(config)
        var n = state
        n.active = true; n.phase = "focus"; n.round = 1; n.rounds = 4
        n.focusMin = f; n.shortMin = s; n.longMin = l
        n.total = Double(f * 60); n.end = Date().addingTimeInterval(n.total); n.pausedLeft = nil
        n.task = task.trimmingCharacters(in: .whitespaces)
        n.countdown = countdown?.id; n.countdownTitle = countdown?.title
        n.session = String(UUID().uuidString.lowercased().prefix(8))
        commit(n)
    }

    /// Nächste Phase beginnen (nach einer Pause wartet der Fokus auf „Start“)
    func startNext() {
        guard waiting else { return }
        var n = state; n.end = Date().addingTimeInterval(n.total); commit(n)
    }

    func togglePause() {
        var n = state
        if let p = n.pausedLeft { n.end = Date().addingTimeInterval(p); n.pausedLeft = nil }
        else if let e = n.end { n.pausedLeft = max(1, e.timeIntervalSinceNow); n.end = nil }
        commit(n)
    }

    /// Phase vorzeitig beenden: Fokus → bisherige Minuten zählen, weiter zur Pause; Pause → zur nächsten Runde
    func skip() {
        guard state.active else { return }
        var n = state
        if n.isFocus { logElapsed(&n) }
        advance(&n, at: Date(), chime: false, autoBreak: true)
        commit(n)
    }

    /// Sitzung beenden (bisherige Fokus-Minuten zählen)
    func stop() {
        var n = state
        if n.isFocus && (n.end != nil || n.pausedLeft != nil) { logElapsed(&n) }
        n.active = false; n.end = nil; n.pausedLeft = nil; n.phase = "focus"; n.round = 1
        commit(n)
    }

    private func logElapsed(_ n: inout FocusSnapshot) {
        let done = n.total - (n.pausedLeft ?? max(0, (n.end ?? Date()).timeIntervalSinceNow))
        let m = Int((done / 60).rounded())
        if m >= 1 { addLog(&n, minutes: m) }
    }

    private func addLog(_ n: inout FocusSnapshot, minutes: Int) {
        let id = n.session + "-\(n.round)"
        guard !n.log.contains(where: { $0.id == id }) else { return }
        n.log.append(FocusLog(id: id, day: FocusSnapshot.day(Date()), minutes: minutes, task: n.task, countdown: n.countdown))
        if n.log.count > 600 { n.log.removeFirst(n.log.count - 600) }
    }

    /// Phase ist vorbei: Fokus → Pause (startet von selbst), Pause → nächste Runde (wartet auf Start)
    private func advance(_ n: inout FocusSnapshot, at end: Date, chime: Bool, autoBreak: Bool) {
        if n.isFocus {
            let long = n.round % max(1, n.rounds) == 0
            n.phase = long ? "long" : "short"
            n.total = Double((long ? n.longMin : n.shortMin) * 60)
            n.pausedLeft = nil
            let newEnd = end.addingTimeInterval(n.total)
            if autoBreak && newEnd > Date() { n.end = newEnd }
            else { n.phase = "focus"; n.round = long ? 1 : n.round + 1; n.total = Double(n.focusMin * 60); n.end = nil }
            if chime { ding() }
        } else {
            let wasLong = n.phase == "long"
            n.phase = "focus"; n.round = wasLong ? 1 : n.round + 1
            n.total = Double(n.focusMin * 60); n.end = nil; n.pausedLeft = nil
            if chime { ding() }
        }
    }

    private func ding() {
        guard UIApplication.shared.applicationState == .active else { return }
        AudioServicesPlaySystemSound(1013)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Uhr

    private func run() {
        guard clock == nil else { return }
        clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] now in
            Task { @MainActor in self?.step(now) }
        }
    }

    private func step(_ now: Date) {
        guard state.active else { return }
        tick = now
        if let e = state.end, e <= now {
            var n = state
            if n.isFocus { addLog(&n, minutes: Int((n.total / 60).rounded())) }
            advance(&n, at: e, chime: true, autoBreak: true)
            commit(n)
        }
    }

    // MARK: Speichern & Abgleich

    private func commit(_ s: FocusSnapshot, push: Bool = true) {
        var s = s
        if push { s.updated = Date() }
        state = s
        tick = Date()
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
        schedule()
        if push { pushRemote() }
    }

    /// Mitteilung, wenn die Phase endet (falls die App im Hintergrund ist)
    private func schedule() {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["fokus"])
        guard state.active, let e = state.end, e > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = state.isFocus ? "Fokus geschafft 🎉" : "Pause vorbei"
        content.body = state.isFocus ? "Zeit für eine Pause." + (state.task.isEmpty ? "" : " (" + state.task + ")") : "Weiter mit Runde \(state.phase == "long" ? 1 : state.round + 1)?"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, e.timeIntervalSinceNow), repeats: false)
        c.add(UNNotificationRequest(identifier: "fokus", content: content, trigger: trigger))
    }

    private func pushRemote() {
        guard !remoteMissing, let uid = SupabaseClient.shared.userId else { return }
        let row = FocusRow(user_id: uid, state: state, updated_at: ISO.string(state.updated))
        Task {
            do { try await SupabaseClient.shared.upsert("user_focus", [row]) }
            catch { print("Fokus-Abgleich:", error) }
        }
    }

    /// Stand der anderen Geräte holen: neuerer Stand gewinnt, Statistik wird zusammengeführt
    func pull() async {
        guard let uid = SupabaseClient.shared.userId else { return }
        do {
            let rows: [FocusRow] = try await SupabaseClient.shared.select("user_focus", ["user_id": "eq." + uid])
            remoteMissing = false; remoteReady = true
            guard let remote = rows.first?.state else { if state.updated > .distantPast { pushRemote() }; return }
            var merged = remote.updated > state.updated ? remote : state
            let ids = Set(merged.log.map(\.id))
            let extra = (remote.updated > state.updated ? state.log : remote.log).filter { !ids.contains($0.id) }
            merged.log = (merged.log + extra).sorted { ($0.day, $0.id) < ($1.day, $1.id) }
            if merged != state { commit(merged, push: false) }
            if merged.log.count != remote.log.count || merged.updated > remote.updated { pushRemote() }
        } catch {
            // Tabelle fehlt (noch): nur auf diesem Gerät
            if "\(error)".contains("404") || "\(error)".contains("PGRST205") || "\(error)".contains("42P01") { remoteMissing = true }
        }
    }
}

// MARK: Bausteine

struct FocusRing: View {
    var line: CGFloat = 10
    @ObservedObject private var center = FocusCenter.shared
    var body: some View {
        let s = center.state
        let color: Color = !s.active ? Color(UIColor.tertiarySystemFill) : center.paused ? .gray : s.isFocus ? Theme.accent : .mint
        ZStack {
            Circle().stroke(Color(UIColor.tertiarySystemFill), lineWidth: line)
            Circle().trim(from: 0, to: s.active ? max(0.001, 1 - center.progress) : 1)
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: center.progress)
        }
    }
}

/// Alle anstehenden Countdowns (für „Lernen für …“), Prüfungen zuerst
func focusCountdowns(_ store: AppStore) -> [CountdownBucket.Entry] {
    let all = store.buckets.filter { $0.bucket == CountdownBucket.kind.id }.flatMap { CountdownBucket.entries($0.config) }
    return all.filter { $0.upcoming }.sorted { a, b in
        (a.type == .pruefung ? 0 : 1, a.date) < (b.type == .pruefung ? 0 : 1, b.date)
    }
}

// MARK: Widget

struct FocusGlance: View {
    let instance: BucketInstance
    @ObservedObject private var center = FocusCenter.shared
    @Environment(\.glanceSpace) private var space

    var body: some View {
        let s = center.state
        let small = space.height < 120
        HStack(spacing: 14) {
            if s.active {
                ZStack {
                    FocusRing(line: small ? 5 : 7)
                    Text(FocusCenter.clock(center.left)).font((small ? Font.caption : .subheadline).weight(.semibold).monospacedDigit())
                }
                .frame(width: small ? 58 : 84, height: small ? 58 : 84)
                VStack(alignment: .leading, spacing: 3) {
                    Text(center.paused ? "Pausiert" : center.waiting ? "Bereit für Runde \(s.round)" : s.phaseName)
                        .font(.caption.weight(.semibold)).foregroundColor(s.isFocus && !center.paused ? Theme.accent : Theme.secondary)
                    Text(s.task.isEmpty ? "Fokus" : s.task).font(.headline).lineLimit(1)
                    if !small, let e = s.end {
                        Text("bis " + Fmt.hhmm(e) + " · Runde \(s.round) von \(s.rounds)").font(.caption).foregroundColor(Theme.secondary)
                    }
                }
                Spacer(minLength: 4)
                Button { center.waiting ? center.startNext() : center.togglePause() } label: {
                    Image(systemName: center.running ? "pause.fill" : "play.fill").font(.title3)
                        .foregroundColor(.white).frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(center.running ? "Pausieren" : "Weiter")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(s.today) min").font(.system(size: small ? 26 : 34, weight: .bold).monospacedDigit())
                    Text("heute fokussiert").font(.subheadline).foregroundColor(Theme.secondary)
                    if !small && s.streak > 0 {
                        Label("\(s.streak) \(s.streak == 1 ? "Tag" : "Tage") in Folge", systemImage: "flame.fill")
                            .font(.caption.weight(.semibold)).foregroundColor(.orange)
                    }
                }
                Spacer(minLength: 4)
                Button {
                    center.start(task: s.recentTasks.first ?? "", countdown: nil, config: instance.config)
                } label: {
                    Image(systemName: "play.fill").font(.title2).foregroundColor(.white)
                        .frame(width: 54, height: 54).background(Circle().fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fokus starten")
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: App

struct FocusApp: View {
    var bucketId: String? = nil
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var center = FocusCenter.shared
    @State private var task = ""
    @State private var link: CountdownBucket.Entry?

    private var config: [String: JSON] {
        (bucketId.flatMap { id in store.buckets.first { $0.id == id } } ?? store.buckets.first { $0.bucket == FocusBucket.kind.id })?.config
            ?? FocusBucket.kind.defaultConfig
    }

    var body: some View {
        let s = center.state
        ScrollView {
            VStack(spacing: 22) {
                // Ring mit Zeit
                ZStack {
                    FocusRing(line: 14)
                    VStack(spacing: 4) {
                        Text(!s.active ? "Bereit" : center.paused ? "Pausiert" : center.waiting ? "Runde \(s.round) von \(s.rounds)" : s.phaseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(s.active && s.isFocus && !center.paused ? Theme.accent : Theme.secondary)
                        Text(FocusCenter.clock(s.active ? center.left : Double(FocusBucket.durations(config).0 * 60)))
                            .font(.system(size: 58, weight: .semibold).monospacedDigit())
                        if s.active {
                            Text(s.task.isEmpty ? "Fokus" : s.task).font(.headline).lineLimit(1)
                            if let t = s.countdownTitle { Label(t, systemImage: "hourglass").font(.caption).foregroundColor(Theme.secondary) }
                        }
                    }
                    .padding(30)
                }
                .frame(width: 280, height: 280)
                .padding(.top, 8)

                if !s.active { setup } else { controls }

                stats
                Text("Läuft auf all deinen Geräten – pausieren und beenden geht überall.")
                    .font(.caption).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Fokus")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if center.state.active {
                    // Kleinmachen: zurück, unten bleibt die Kapsel
                    Button { dismiss() } label: { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                        .accessibilityLabel("Verkleinern")
                }
            }
        }
        .task { await center.pull() }
    }

    // Vor dem Start: Aufgabe, Countdown, Dauer
    private var setup: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Woran arbeitest du?", text: $task)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
            let recent = center.state.recentTasks
            if !recent.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recent, id: \.self) { t in
                            Button { task = t } label: {
                                Text(t).font(.subheadline).foregroundColor(task == t ? .white : .primary)
                                    .padding(.horizontal, 12).frame(height: 34)
                                    .background(Capsule().fill(task == t ? Theme.accent : Color(UIColor.tertiarySystemFill)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            let cds = focusCountdowns(store)
            if !cds.isEmpty {
                Menu {
                    Button { link = nil } label: { Label("Ohne Countdown", systemImage: "xmark") }
                    ForEach(cds) { e in
                        Button { link = e; if task.isEmpty { task = e.title } } label: { Text(e.emoji + " " + e.title) }
                    }
                } label: {
                    HStack {
                        Image(systemName: "hourglass")
                        Text(link.map { "Für: " + $0.emoji + " " + $0.title } ?? "Mit Countdown verknüpfen (z. B. Prüfung)")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                }
            }
            Picker("Dauer", selection: presetBinding) {
                ForEach(FocusBucket.presets, id: \.id) { Text($0.label + " min").tag($0.id) }
            }
            .pickerStyle(.segmented)
            Button { center.start(task: task, countdown: link, config: config) } label: {
                Label("Fokus starten", systemImage: "play.fill").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
            }
            .buttonStyle(.plain)
        }
    }

    private var presetBinding: Binding<String> {
        Binding(get: { config["preset"]?.string ?? "25/5/15" }, set: { v in
            if let id = bucketId ?? store.buckets.first(where: { $0.bucket == FocusBucket.kind.id })?.id {
                store.updateConfig(id) { $0["preset"] = .string(v) }
            }
        })
    }

    // Während der Sitzung
    private var controls: some View {
        VStack(spacing: 12) {
            if center.waiting {
                bigButton(center.state.isFocus ? "Runde \(center.state.round) starten" : "Pause starten", "play.fill") { center.startNext() }
            } else {
                bigButton(center.paused ? "Weiter" : "Pausieren", center.paused ? "play.fill" : "pause.fill") { center.togglePause() }
            }
            HStack(spacing: 12) {
                smallButton(center.state.isFocus ? "Zur Pause" : "Pause überspringen", "forward.end.fill") { center.skip() }
                smallButton("Beenden", "stop.fill", role: .destructive) { center.stop() }
            }
        }
    }

    private func bigButton(_ t: String, _ sym: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(t, systemImage: sym).font(.headline).foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
        }
        .buttonStyle(.plain)
    }
    private func smallButton(_ t: String, _ sym: String, role: ButtonRole? = nil, _ action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(t, systemImage: sym).font(.subheadline.weight(.semibold))
                .foregroundColor(role == .destructive ? .red : Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }

    // Statistik
    private var stats: some View {
        let s = center.state
        let week = s.week
        let maxM = max(30, week.map(\.minutes).max() ?? 0)
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEEEE"
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                stat("\(s.today) min", "heute")
                Divider().frame(height: 36)
                stat("\(s.streak)", s.streak == 1 ? "Tag in Folge" : "Tage in Folge")
                Divider().frame(height: 36)
                stat(hours(week.reduce(0) { $0 + $1.minutes }), "diese Woche")
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(week, id: \.day) { d in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Calendar.current.isDateInToday(d.day) ? Theme.accent : Theme.accent.opacity(0.35))
                            .frame(height: max(3, 80 * CGFloat(d.minutes) / CGFloat(maxM)))
                        Text(f.string(from: d.day)).font(.caption2).foregroundColor(Theme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100, alignment: .bottom)
            let tasks = s.byTask.prefix(5)
            if !tasks.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(tasks), id: \.task) { t in
                        HStack {
                            Text(t.task).lineLimit(1)
                            Spacer()
                            Text(hours(t.minutes)).monospacedDigit().foregroundColor(Theme.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.title3.weight(.bold).monospacedDigit())
            Text(l).font(.caption).foregroundColor(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// „1 h 20 min“ / „45 min“
func hours(_ m: Int) -> String { m >= 60 ? "\(m / 60) h" + (m % 60 > 0 ? " \(m % 60) min" : "") : "\(m) min" }

/// Fokus als Blatt (aus der Kapsel unten)
struct FocusSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            FocusApp()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }
}
