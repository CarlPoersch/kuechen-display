import SwiftUI
import Combine

// ============================================================
// Uhr: Wecker | Timer (später: Stoppuhr). Ersetzt die reine Timer-App.
// Widget „Wecker“: nächster Wecker auf der Startseite.
// Design: docs/specs/2026-11-24-uhr-wecker-design.md
// Für alle Geräte gebaut: Listen und Formulare passen sich iPhone und iPad an.
// ============================================================

enum ClockBucket {
    /// Widget der Uhr: nächster Wecker
    static let alarmWidget = BucketKind(
        id: "wecker", name: "Wecker", symbol: "alarm.fill", tint: .orange, art: .glance,
        interests: ["haushalt"], blurb: "Dein nächster Wecker auf einen Blick – mit einem Tipp an- oder ausschalten.",
        glance: { _, _ in AnyView(NextAlarmGlance()) },
        detail: { _ in AnyView(ClockView(start: .alarm)) },
        itemLinks: true,
        parent: "timer"
    )
}

// MARK: Die App

struct ClockView: View {
    enum Tab: String, CaseIterable { case alarm, timer, stopwatch }
    @State private var tab: Tab

    init(start: Tab? = nil) {
        let saved = Tab(rawValue: UserDefaults.standard.string(forKey: "clock.tab") ?? "") ?? .alarm
        _tab = State(initialValue: start ?? saved)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $tab) {
                Text("Wecker").tag(Tab.alarm)
                Text("Timer").tag(Tab.timer)
                Text("Stoppuhr").tag(Tab.stopwatch)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
            switch tab {
            case .alarm: AlarmListView()
            case .timer: TimerToolView()
            case .stopwatch: StopwatchView()
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: tab) { UserDefaults.standard.set($0.rawValue, forKey: "clock.tab") }
    }
}

// MARK: Wecker-Liste

struct AlarmListView: View {
    @ObservedObject private var center = AlarmCenter.shared
    @Environment(\.horizontalSizeClass) private var size
    @ObservedObject private var smart = SmartHomeStore.shared
    @ObservedObject private var host = LightHost.shared
    @ObservedObject private var night = NightClock.shared
    @State private var editing: Alarm?
    @State private var isNew = false
    @State private var goodNight = false

    var body: some View {
        List {
            Section {
                Button { goodNight = true } label: {
                    Label("Gute Nacht", systemImage: "moon.zzz.fill").font(.body.weight(.semibold))
                }
            }
            if center.alarms.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Noch kein Wecker").font(.headline)
                        Text("Stell einen Wecker – er klingelt in Hubert und als Mitteilung, wenn Hubert zu ist.")
                            .font(.subheadline).foregroundColor(Theme.secondary)
                    }
                    .padding(.vertical, 4)
                    Button { add() } label: { Label("Wecker stellen", systemImage: "plus") }
                }
            } else {
                Section {
                    ForEach(center.sorted) { a in
                        AlarmRow(alarm: a, big: size == .regular)
                            .contentShape(Rectangle())
                            .onTapGesture { isNew = false; editing = a }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { center.delete(a) } label: { Label("Löschen", systemImage: "trash") }
                            }
                            .contextMenu {
                                if a.enabled && a.nextFire() != nil || center.isSkipped(a) {
                                    Button { center.skipNext(a, !center.isSkipped(a)) } label: {
                                        Label(center.isSkipped(a) ? "Nicht mehr überspringen" : "Nächstes Mal überspringen",
                                              systemImage: "forward.end")
                                    }
                                }
                                Button(role: .destructive) { center.delete(a) } label: { Label("Löschen", systemImage: "trash") }
                            }
                    }
                } header: {
                    if let n = center.next { Text("Nächster: " + NextAlarmGlance.when(n.fire)) }
                } footer: {
                    Text("Klingelt in Hubert mit Ton. Ist Hubert zu, kommt eine Mitteilung. Beenden oder Schlummern gilt auf allen Geräten.")
                }
            }
            Section {
                Toggle("Standby-Knopf auf der Startseite", isOn: $night.standbyButton).tint(Theme.accent)
                Toggle("Wanddisplay", isOn: $host.isWall).tint(Theme.accent)
                if host.isWall {
                    Toggle("Nachtuhr automatisch", isOn: $night.autoOn).tint(Theme.accent)
                    if night.autoOn {
                        DatePicker("Ab", selection: night.binding(\.fromMin), displayedComponents: .hourAndMinute)
                        DatePicker("Bis", selection: night.binding(\.toMin), displayedComponents: .hourAndMinute)
                    }
                    Button("Nachtuhr jetzt") { NightClock.shared.start() }
                }
            } header: { Text("Dieses Gerät") } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.isWall
                         ? "Die Nachtuhr macht den Bildschirm ganz dunkel. Antippen beendet sie, der Wecker weckt sie auf."
                         : "Wanddisplays zeigen nachts die Nachtuhr\(smart.lights.isEmpty ? "" : " und schalten bevorzugt das Licht").")
                    if !smart.lights.isEmpty { LightHostNote() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { add() } label: { Image(systemName: "plus") }.accessibilityLabel("Wecker stellen")
            }
        }
        .sheet(item: $editing) { a in AlarmEditSheet(alarm: a, isNew: isNew) }
        .sheet(isPresented: $goodNight) { GoodNightSheet() }
    }

    private func add() {
        guard let a = center.newAlarm() else { return }
        isNew = true
        editing = a
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    var big = false
    @ObservedObject private var center = AlarmCenter.shared

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.timeText)
                    .font(.system(size: big ? 52 : 44, weight: .light).monospacedDigit())
                    .foregroundColor(alarm.enabled ? .primary : Theme.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(subtitle).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { alarm.enabled }, set: { center.toggle(alarm, on: $0) }))
                .labelsHidden().tint(Theme.accent)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = [alarm.title, alarm.daysText]
        if center.isSkipped(alarm) { parts.append("nächstes Mal übersprungen") }
        return parts.joined(separator: " · ")
    }
}

// MARK: Wecker bearbeiten

struct AlarmEditSheet: View {
    let isNew: Bool
    @State private var a: Alarm
    @ObservedObject private var center = AlarmCenter.shared
    @ObservedObject private var smart = SmartHomeStore.shared
    @Environment(\.dismiss) private var dismiss

    init(alarm: Alarm, isNew: Bool) {
        self.isNew = isNew
        _a = State(initialValue: alarm)
    }

    private var time: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: a.hour, minute: a.minute, second: 0, of: Date()) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            a.hour = c.hour ?? a.hour; a.minute = c.minute ?? a.minute
        })
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("Uhrzeit", selection: time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel).labelsHidden()
                        .frame(maxWidth: .infinity)
                }
                Section {
                    WeekdayPicker(days: $a.days)
                } header: { Text("Wiederholen") } footer: {
                    Text(a.days.isEmpty ? "Kein Tag gewählt: klingelt einmal und schaltet sich danach ab." : a.daysText)
                }
                Section {
                    HStack {
                        Text("Name")
                        TextField("Wecker", text: $a.name).multilineTextAlignment(.trailing)
                    }
                    Picker("Schlummern", selection: $a.snooze_min) {
                        ForEach([5, 9, 10, 15], id: \.self) { Text("\($0) Min.").tag($0) }
                    }
                    Picker("Ton", selection: Binding(get: { AlarmTone.from(a.sound) }, set: { t in
                        a.sound = t.rawValue
                        AlarmSound.shared.preview(t)          // gleich vorspielen
                    })) {
                        ForEach(AlarmTone.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Langsam lauter", isOn: $a.ramp).tint(Theme.accent)
                } footer: {
                    Text("Klingelt auf allen Geräten im Haushalt. Beenden oder Schlummern auf einem Gerät gilt für alle.")
                }
                // Licht – nur mit Smart Home und Lampen
                if !smart.lights.isEmpty {
                    Section {
                        NavigationLink(destination: LampPicker(selection: $a.lamps)) {
                            HStack {
                                Text("Lampen")
                                Spacer()
                                Text(LampPicker.summary(a.lamps)).foregroundColor(Theme.secondary)
                            }
                        }
                        if !a.lamps.isEmpty {
                            Picker("Anschalten", selection: $a.light_lead) {
                                Text("Beim Klingeln").tag(0)
                                ForEach([5, 10, 15], id: \.self) { Text("\($0) Min. vorher").tag($0) }
                            }
                            if a.light_lead > 0 && a.lamps.count > 1 {
                                Toggle("Nacheinander", isOn: $a.light_stagger).tint(Theme.accent)
                            }
                        }
                    } header: { Text("Licht") } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if !a.lamps.isEmpty {
                                Text(a.light_stagger && a.light_lead > 0 && a.lamps.count > 1
                                     ? "Die Lampen gehen eine nach der anderen an – die letzte zur Weckzeit."
                                     : "Beenden lässt das Licht an, Schlummern schaltet es bis zum nächsten Klingeln aus.")
                            }
                            LightHostNote()
                        }
                    }
                }
                if !isNew {
                    Section {
                        if a.enabled && a.nextFire() != nil || center.isSkipped(a) {
                            Button(center.isSkipped(a) ? "Nicht mehr überspringen" : "Nächstes Mal überspringen") {
                                center.skipNext(a, !center.isSkipped(a)); dismiss()
                            }
                        }
                        Button("Wecker löschen", role: .destructive) { center.delete(a); dismiss() }
                    }
                }
            }
            .navigationTitle(isNew ? "Neuer Wecker" : "Wecker").navigationBarTitleDisplayMode(.inline)
            .onDisappear { if AlarmCenter.shared.ringing == nil { AlarmSound.shared.stop() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var s = a
                        s.name = s.name.trimmingCharacters(in: .whitespaces)
                        if isNew { s.enabled = true }
                        center.save(s); dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

/// Sieben runde Tages-Knöpfe (passt auch auf schmale iPhones: 7 × 40 pt)
struct WeekdayPicker: View {
    @Binding var days: [Int]
    private let names = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { d in
                    let on = days.contains(d)
                    Button {
                        if on { days.removeAll { $0 == d } } else { days.append(d); days.sort() }
                    } label: {
                        Text(names[d - 1]).font(.subheadline.weight(.semibold))
                            .foregroundColor(on ? .white : .primary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(on ? Theme.accent : Color(UIColor.tertiarySystemFill)))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(names[d - 1] + (on ? ", gewählt" : ""))
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                quick("Mo–Fr", [1, 2, 3, 4, 5])
                quick("Wochenende", [6, 7])
                quick("Täglich", Array(1...7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }

    private func quick(_ title: String, _ set: [Int]) -> some View {
        Button { days = days == set ? [] : set } label: {
            Text(title).font(.footnote.weight(.semibold))
                .foregroundColor(days == set ? .white : Theme.accent)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(days == set ? Theme.accent : Theme.accent.opacity(0.12)))
        }
        .buttonStyle(.borderless)
    }
}

// MARK: Widget „Wecker“

struct NextAlarmGlance: View {
    struct Upcoming: Identifiable { let alarm: Alarm; let fire: Date; var id: String { alarm.id } }

    @ObservedObject private var center = AlarmCenter.shared
    @ObservedObject private var smart = SmartHomeStore.shared
    @Environment(\.glanceSpace) private var space
    @Environment(\.openBucketDetail) private var openDetail
    @State private var goodNight = false

    var body: some View {
        let upcoming: [Upcoming] = center.alarms.filter(center.ringsHere)
            .compactMap { a in a.nextFire().map { Upcoming(alarm: a, fire: $0) } }
            .sorted { $0.fire < $1.fire }
        if let first = upcoming.first {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(first.alarm.timeText)
                            .font(.system(size: space.width > 500 ? 56 : 44, weight: .light).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(Self.when(first.fire) + " · " + first.alarm.title)
                            .font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    MiniSwitch(isOn: Binding(get: { first.alarm.enabled }, set: { center.toggle(first.alarm, on: $0) }),
                               label: "Wecker \(first.alarm.timeText)")
                }
                Button { goodNight = true } label: {
                    Label("Gute Nacht", systemImage: "moon.zzz.fill").font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 14).frame(minHeight: 36)
                        .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
                .buttonStyle(.borderless)
                // Weitere Wecker, wenn Platz ist
                let room = max(0, Int((space.height - 126) / 30))
                ForEach(Array(upcoming.dropFirst().prefix(room))) { u in
                    HStack {
                        Text(u.alarm.timeText).font(.body.monospacedDigit())
                        Text(Self.when(u.fire)).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                        Spacer()
                    }
                }
            }
            // Tipp irgendwo auf die Karte öffnet die Uhr (Schalter und „Gute Nacht“ behalten ihre Funktion)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { openDetail() }
            .sheet(isPresented: $goodNight) { GoodNightSheet() }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(center.alarms.isEmpty ? "Kein Wecker gestellt" : "Alle Wecker aus").font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { openDetail() } label: {
                    Text("Wecker stellen").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        .padding(.horizontal, 16).frame(minHeight: 36)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.borderless)
            }
            .contentShape(Rectangle())
            .onTapGesture { openDetail() }
        }
    }

    /// „Heute“, „Morgen“ oder Wochentag, dazu „in 7 Std. 12 Min.“
    static func when(_ d: Date) -> String {
        let cal = Calendar.current
        let day: String
        if cal.isDateInToday(d) { day = "Heute" }
        else if cal.isDateInTomorrow(d) { day = "Morgen" }
        else {
            let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEEE"
            day = f.string(from: d)
        }
        let mins = max(0, Int(d.timeIntervalSinceNow / 60))
        let rel = mins < 60 ? "in \(mins) Min." : mins < 24 * 60 ? "in \(mins / 60) Std. \(mins % 60) Min." : ""
        return rel.isEmpty ? day : day + ", " + rel
    }
}


// MARK: Gute Nacht (nur mit Lampen)

struct GoodNightSheet: View {
    @ObservedObject private var center = AlarmCenter.shared
    @ObservedObject private var smart = SmartHomeStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Alarm?

    var body: some View {
        NavigationView {
            List {
                Section {
                    if let n = center.next {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.alarm.timeText).font(.system(size: 44, weight: .light).monospacedDigit())
                                Text(NextAlarmGlance.when(n.fire) + " · " + n.alarm.title)
                                    .font(.subheadline).foregroundColor(Theme.secondary)
                            }
                            Spacer()
                            Button("Ändern") { editing = n.alarm }.buttonStyle(.borderless)
                        }
                        Button("Diesmal überspringen") { center.skipNext(n.alarm, true) }
                    } else {
                        Text("Kein Wecker gestellt.").foregroundColor(Theme.secondary)
                        Button("Wecker stellen") { editing = center.newAlarm() }
                    }
                } header: { Text("Nächster Wecker") }

                Section {
                    Button {
                        if !smart.lights.isEmpty { smart.switchLights(smart.lights.map(\.id), on: false) }
                        NightClock.shared.request(household: TimerCenter.shared.household)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } label: {
                        Text("Gute Nacht").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text(smart.lights.isEmpty ? "Wanddisplays wechseln in die Nachtuhr."
                                              : "Alle Lampen gehen aus, Wanddisplays wechseln in die Nachtuhr.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Gute Nacht").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .sheet(item: $editing) { a in AlarmEditSheet(alarm: a, isNew: !center.alarms.contains { $0.id == a.id }) }
        }
        .navigationViewStyle(.stack)
    }
}


// MARK: Stoppuhr (pro Gerät; merkt sich die Startzeit und läuft darum auch bei geschlossener App weiter)

final class Stopwatch: ObservableObject {
    static let shared = Stopwatch()
    @Published private(set) var startedAt: Date?
    @Published private(set) var stored: TimeInterval = 0          // Zeit vor dem letzten Start
    @Published private(set) var laps: [TimeInterval] = []        // Rundenzeiten (je Runde)
    private let d = UserDefaults.standard

    init() {
        let t = d.double(forKey: "stopwatch.started")
        startedAt = t > 0 ? Date(timeIntervalSince1970: t) : nil
        stored = d.double(forKey: "stopwatch.stored")
        laps = (d.array(forKey: "stopwatch.laps") as? [Double]) ?? []
    }

    var running: Bool { startedAt != nil }
    func elapsed(_ now: Date = Date()) -> TimeInterval { stored + (startedAt.map { now.timeIntervalSince($0) } ?? 0) }
    var lapTotal: TimeInterval { laps.reduce(0, +) }

    func startStop() {
        if let s = startedAt { stored += Date().timeIntervalSince(s); startedAt = nil } else { startedAt = Date() }
        save()
    }

    func lapOrReset() {
        if running { laps.append(elapsed() - lapTotal) } else { stored = 0; laps = [] }
        save()
    }

    private func save() {
        d.set(startedAt?.timeIntervalSince1970 ?? 0, forKey: "stopwatch.started")
        d.set(stored, forKey: "stopwatch.stored")
        d.set(laps, forKey: "stopwatch.laps")
    }

    static func format(_ t: TimeInterval) -> String {
        let cs = Int((t * 100).rounded(.down))
        let h = cs / 360_000, m = cs / 6000 % 60, s = cs / 100 % 60, c = cs % 100
        return h > 0 ? String(format: "%d:%02d:%02d,%02d", h, m, s, c) : String(format: "%02d:%02d,%02d", m, s, c)
    }
}

struct StopwatchView: View {
    @ObservedObject private var sw = Stopwatch.shared
    @Environment(\.horizontalSizeClass) private var size

    var body: some View {
        let big = size == .regular
        List {
            Section {
                VStack(spacing: big ? 28 : 20) {
                    TimelineView(.periodic(from: .now, by: sw.running ? 0.05 : 3600)) { ctx in
                        Text(Stopwatch.format(sw.elapsed(ctx.date)))
                            .font(.system(size: big ? 96 : 64, weight: .thin).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                    }
                    HStack {
                        roundButton(sw.running ? "Runde" : "Zurücksetzen", fill: Color(UIColor.tertiarySystemFill), text: .primary) {
                            sw.lapOrReset()
                        }
                        .disabled(!sw.running && sw.elapsed() == 0)
                        Spacer()
                        roundButton(sw.running ? "Stopp" : "Start", fill: sw.running ? Color.red.opacity(0.18) : Color.green.opacity(0.2),
                                    text: sw.running ? .red : .green) { sw.startStop() }
                    }
                    .frame(maxWidth: 420)
                }
                .padding(.vertical, big ? 24 : 12)
                .frame(maxWidth: .infinity)
            }
            if !sw.laps.isEmpty {
                Section("Runden") {
                    let best = sw.laps.min(), worst = sw.laps.count > 2 ? sw.laps.max() : nil
                    ForEach(sw.laps.indices.reversed(), id: \.self) { i in
                        let lap = sw.laps[i]
                        HStack {
                            Text("Runde \(i + 1)")
                            Spacer()
                            Text(Stopwatch.format(lap)).monospacedDigit()
                        }
                        .foregroundColor(sw.laps.count > 1 && lap == best ? .green : lap == worst ? .red : .primary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func roundButton(_ title: String, fill: Color, text: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundColor(text)
                .frame(width: 88, height: 88)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.borderless)
    }
}


/// Schalter im iOS-Stil mit fester Größe (51 × 31 pt). Warum nicht Toggle: Auf iOS 26 zeichnet der
/// System-Schalter größer, als er meldet – in Karten wurde er rechts abgeschnitten.
struct MiniSwitch: View {
    @Binding var isOn: Bool
    var label: String = ""

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { isOn.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Theme.accent : Color(UIColor.systemFill))
                Circle().fill(Color.white).padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 51, height: 31)
            .padding(.vertical, 6)            // größere Tippfläche (≥ 43 pt)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "Ein" : "Aus")
        .accessibilityAddTraits(.isButton)
    }
}
