import SwiftUI

// ============================================================
// Stundenplan: Was ist jetzt, was kommt als Nächstes – mit Raum.
// Einstellungen: lessons = [{ id, title, room, day (1 = Mo … 7 = So), start "08:15", end "09:45", kind }]
//                pause (Bool) = vorlesungsfrei
// ============================================================

enum StundenplanBucket {
    static let kind = BucketKind(
        id: "stundenplan", name: "Stundenplan", symbol: "graduationcap", tint: .blue, art: .glance,
        interests: ["lernen"], blurb: "Nächste Vorlesung mit Raum und Uhrzeit – und was heute noch kommt.",
        glance: { inst, size in AnyView(StundenplanGlance(config: inst.config)) },
        detail: { inst in AnyView(StundenplanApp(bucketId: inst.id)) },
        settings: { binding in AnyView(StundenplanSettings(config: binding)) }
    )

    struct Lesson: Identifiable, Equatable {
        var id = UUID().uuidString.lowercased()
        var title: String
        var room = ""
        var day: Int            // 1 = Montag … 7 = Sonntag
        var start: Int          // Minuten seit Mitternacht
        var end: Int
        var kind = "Vorlesung"
    }

    static let kinds = ["Vorlesung", "Übung", "Seminar", "Praktikum", "Tutorium", "Sonstiges"]
    static let dayNames = ["", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    static func lessons(_ c: [String: JSON]) -> [Lesson] {
        (c["lessons"]?.array ?? []).compactMap { j in
            guard let o = j.object, let t = o["title"]?.string, let d = o["day"]?.double,
                  let s = o["start"]?.string.flatMap({ minutes($0) }), let e = o["end"]?.string.flatMap({ minutes($0) }) else { return nil }
            return Lesson(id: o["id"]?.string ?? UUID().uuidString, title: t, room: o["room"]?.string ?? "", day: Int(d),
                          start: s, end: e, kind: o["kind"]?.string ?? "Vorlesung")
        }
        .sorted { ($0.day, $0.start) < ($1.day, $1.start) }
    }

    static func store(_ list: [Lesson], in c: inout [String: JSON]) {
        c["lessons"] = .array(list.map { l in
            JSON.object(["id": .string(l.id), "title": .string(l.title), "room": .string(l.room), "day": .number(Double(l.day)),
                         "start": .string(clock(l.start)), "end": .string(clock(l.end)), "kind": .string(l.kind)])
        })
    }

    static func minutes(_ s: String) -> Int? {
        let p = s.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return nil }
        return p[0] * 60 + p[1]
    }
    static func clock(_ m: Int) -> String { String(format: "%02d:%02d", m / 60, m % 60) }

    /// Wochentag heute: 1 = Montag … 7 = Sonntag
    static func weekday(_ d: Date = Date()) -> Int {
        let w = Calendar.current.component(.weekday, from: d)   // 1 = Sonntag
        return w == 1 ? 7 : w - 1
    }
    static func nowMinutes() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Nächster Tag mit Veranstaltungen (ab morgen) und wie viele Tage bis dahin
    static func nextDay(_ list: [Lesson]) -> (day: Int, inDays: Int)? {
        let today = weekday()
        for off in 1...7 {
            let d = (today - 1 + off) % 7 + 1
            if list.contains(where: { $0.day == d }) { return (d, off) }
        }
        return nil
    }
}

// MARK: Karte

struct StundenplanGlance: View {
    let config: [String: JSON]
    @Environment(\.glanceSpace) private var space

    var body: some View {
        // Minütlich neu, damit „jetzt“ stimmt
        TimelineView(.periodic(from: Date(), by: 60)) { _ in content }
    }

    @ViewBuilder private var content: some View {
        let all = StundenplanBucket.lessons(config)
        let now = StundenplanBucket.nowMinutes()
        let today = all.filter { $0.day == StundenplanBucket.weekday() && $0.end > now }
        if all.isEmpty {
            Text("Trag deine Vorlesungen ein").foregroundColor(Theme.secondary)
        } else if config["pause"]?.bool == true {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vorlesungsfrei 🎉").font(.headline)
                Text("Der Stundenplan ruht, bis du ihn wieder einschaltest.").font(.subheadline).foregroundColor(Theme.secondary)
            }
        } else if today.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Heute nichts mehr").font(.headline)
                if let n = StundenplanBucket.nextDay(all), let first = all.first(where: { $0.day == n.day }) {
                    Text((n.inDays == 1 ? "Morgen" : StundenplanBucket.dayNames[n.day]) + " ab " + StundenplanBucket.clock(first.start))
                        .font(.subheadline).foregroundColor(Theme.secondary)
                    LessonLine(lesson: first, live: false)
                }
            }
        } else {
            let rows = fitRows(space.height, row: 46, max: 6)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(today.prefix(rows))) { l in
                    LessonLine(lesson: l, live: l.start <= now)
                }
            }
        }
    }
}

struct LessonLine: View {
    let lesson: StundenplanBucket.Lesson
    let live: Bool
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(live ? Theme.accent : Color.blue.opacity(0.6)).frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(lesson.title).font(.headline).lineLimit(1)
                Text([lesson.room, lesson.kind].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                if live {
                    Text("Jetzt").font(.caption.weight(.semibold)).foregroundColor(Theme.accent)
                    Text("bis " + StundenplanBucket.clock(lesson.end)).font(.subheadline.monospacedDigit())
                } else {
                    Text(StundenplanBucket.clock(lesson.start)).font(.headline.monospacedDigit())
                    Text(StundenplanBucket.clock(lesson.end)).font(.caption.monospacedDigit()).foregroundColor(Theme.secondary)
                }
            }
        }
    }
}

// MARK: App

struct StundenplanApp: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @State private var sheet: StundenplanBucket.Lesson?
    @State private var isNew = false

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        let all = StundenplanBucket.lessons(config)
        let today = StundenplanBucket.weekday()
        List {
            if all.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch leer").font(.headline)
                        Text("Leg deine Vorlesungen einmal an – Hubert zeigt dann immer, was als Nächstes kommt und in welchem Raum.")
                            .font(.subheadline).foregroundColor(Theme.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            ForEach(1...7, id: \.self) { d in
                let list = all.filter { $0.day == d }
                if !list.isEmpty {
                    Section(StundenplanBucket.dayNames[d] + (d == today ? " · heute" : "")) {
                        ForEach(list) { l in
                            Button { isNew = false; sheet = l } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading) {
                                        Text(StundenplanBucket.clock(l.start)).font(.subheadline.monospacedDigit())
                                        Text(StundenplanBucket.clock(l.end)).font(.caption.monospacedDigit()).foregroundColor(Theme.secondary)
                                    }
                                    .frame(width: 48, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(l.title).font(.headline).foregroundColor(.primary)
                                        Text([l.room, l.kind].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.subheadline).foregroundColor(Theme.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { idx in remove(idx.map { list[$0].id }) }
                    }
                }
            }
            Section {
                Button { add() } label: { Label("Veranstaltung hinzufügen", systemImage: "plus.circle.fill") }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { add() } label: { Image(systemName: "plus") }.accessibilityLabel("Veranstaltung hinzufügen")
            }
        }
        .sheet(item: $sheet) { l in
            LessonEditSheet(lesson: l, isNew: isNew, onSave: { save($0) }, onDelete: isNew ? nil : { remove([l.id]) })
        }
    }

    private func add() {
        let d = min(StundenplanBucket.weekday(), 5)
        isNew = true
        sheet = StundenplanBucket.Lesson(title: "", day: d, start: 8 * 60 + 15, end: 9 * 60 + 45)
    }

    private func save(_ l: StundenplanBucket.Lesson) {
        store.updateConfig(bucketId) { c in
            var list = StundenplanBucket.lessons(c)
            if let i = list.firstIndex(where: { $0.id == l.id }) { list[i] = l } else { list.append(l) }
            StundenplanBucket.store(list, in: &c)
        }
    }

    private func remove(_ ids: [String]) {
        store.updateConfig(bucketId) { c in
            StundenplanBucket.store(StundenplanBucket.lessons(c).filter { !ids.contains($0.id) }, in: &c)
        }
    }
}

struct LessonEditSheet: View {
    @State var lesson: StundenplanBucket.Lesson
    let isNew: Bool
    let onSave: (StundenplanBucket.Lesson) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    private func time(_ m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }
    private func mins(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Fach, z. B. Wirtschaftsrecht", text: $lesson.title)
                    TextField("Raum, z. B. K 112", text: $lesson.room)
                    Picker("Art", selection: $lesson.kind) {
                        ForEach(StundenplanBucket.kinds, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section {
                    Picker("Tag", selection: $lesson.day) {
                        ForEach(1...7, id: \.self) { Text(StundenplanBucket.dayNames[$0]).tag($0) }
                    }
                    DatePicker("Beginn", selection: Binding(get: { time(lesson.start) }, set: { lesson.start = mins($0)
                        if lesson.end <= lesson.start { lesson.end = lesson.start + 90 } }), displayedComponents: .hourAndMinute)
                    DatePicker("Ende", selection: Binding(get: { time(lesson.end) }, set: { lesson.end = max(mins($0), lesson.start + 5) }),
                               displayedComponents: .hourAndMinute)
                }
                if let del = onDelete {
                    Section {
                        Button("Löschen", role: .destructive) { del(); dismiss() }
                    }
                }
            }
            .navigationTitle(isNew ? "Neue Veranstaltung" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { onSave(lesson); dismiss() }
                        .disabled(lesson.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct StundenplanSettings: View {
    @Binding var config: [String: JSON]
    var body: some View {
        Toggle("Vorlesungsfrei", isOn: Binding(get: { config["pause"]?.bool ?? false }, set: { config["pause"] = .bool($0) }))
    }
}
