import SwiftUI

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
    enum Tab: String, CaseIterable { case alarm, timer }
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
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
            switch tab {
            case .alarm: AlarmListView()
            case .timer: TimerToolView()
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
    @State private var editing: Alarm?
    @State private var isNew = false

    var body: some View {
        List {
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
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { add() } label: { Image(systemName: "plus") }.accessibilityLabel("Wecker stellen")
            }
        }
        .sheet(item: $editing) { a in AlarmEditSheet(alarm: a, isNew: isNew) }
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
        if !alarm.shared { parts.append("nur ich") }
        if center.isSkipped(alarm) { parts.append("nächstes Mal übersprungen") }
        return parts.joined(separator: " · ")
    }
}

// MARK: Wecker bearbeiten

struct AlarmEditSheet: View {
    let isNew: Bool
    @State private var a: Alarm
    @ObservedObject private var center = AlarmCenter.shared
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
                    Toggle("Für den ganzen Haushalt", isOn: $a.shared).tint(Theme.accent)
                } footer: {
                    Text(a.shared ? "Klingelt auf allen Geräten im Haushalt." : "Klingelt nur auf deinen Geräten.")
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
    @Environment(\.glanceSpace) private var space
    @Environment(\.openBucketDetail) private var openDetail

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
                    Toggle("", isOn: Binding(get: { first.alarm.enabled }, set: { center.toggle(first.alarm, on: $0) }))
                        .labelsHidden().tint(Theme.accent)
                }
                // Weitere Wecker, wenn Platz ist
                let room = max(0, Int((space.height - 80) / 30))
                ForEach(Array(upcoming.dropFirst().prefix(room))) { u in
                    HStack {
                        Text(u.alarm.timeText).font(.body.monospacedDigit())
                        Text(Self.when(u.fire)).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                        Spacer()
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(center.alarms.isEmpty ? "Kein Wecker gestellt" : "Alle Wecker aus").font(.headline)
                Button { openDetail() } label: {
                    Text("Wecker stellen").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        .padding(.horizontal, 16).frame(minHeight: 36)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.borderless)
            }
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
