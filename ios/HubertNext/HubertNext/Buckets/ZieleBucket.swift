import SwiftUI

// ============================================================
// Wochenziele: drei Ziele pro Woche, direkt in der Karte abhaken.
// Neue Woche → die alte wandert in den Verlauf, offene Ziele lassen sich übernehmen.
// Einstellungen: week ("2026-W47"), goals = [{ id, t, done }],
//                history = [{ week, done, total, open: [String] }] (neueste zuerst, max. 26)
// ============================================================

enum ZieleBucket {
    static let kind = BucketKind(
        id: "ziele", name: "Wochenziele", symbol: "checkmark.seal", tint: .green, art: .glance,
        interests: ["lernen", "gesundheit"], blurb: "Drei Ziele pro Woche – in der Karte abhaken, mit Verlauf und Serie.",
        glance: { inst, size in AnyView(ZieleGlance(bucketId: inst.id, config: inst.config)) },
        detail: { inst in AnyView(ZieleApp(bucketId: inst.id)) },
        itemLinks: true
    )

    struct Goal: Identifiable, Equatable { var id = UUID().uuidString.lowercased(); var t: String; var done = false }
    struct Week: Identifiable { let week: String; let done: Int; let total: Int; let open: [String]; var id: String { week } }

    static func weekKey(_ d: Date = Date()) -> String {
        let cal = Calendar(identifier: .iso8601)
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
    }

    /// „KW 47“
    static func weekLabel(_ key: String) -> String { "KW " + String(Int(key.suffix(2)) ?? 0) }

    static func goals(_ c: [String: JSON]) -> [Goal] {
        (c["goals"]?.array ?? []).compactMap { j in
            guard let o = j.object, let t = o["t"]?.string else { return nil }
            return Goal(id: o["id"]?.string ?? t, t: t, done: o["done"]?.bool ?? false)
        }
    }

    static func history(_ c: [String: JSON]) -> [Week] {
        (c["history"]?.array ?? []).compactMap { j in
            guard let o = j.object, let w = o["week"]?.string else { return nil }
            return Week(week: w, done: Int(o["done"]?.double ?? 0), total: Int(o["total"]?.double ?? 0),
                        open: (o["open"]?.array ?? []).compactMap { $0.string })
        }
    }

    static func storeGoals(_ list: [Goal], in c: inout [String: JSON]) {
        c["goals"] = .array(list.map { g in JSON.object(["id": .string(g.id), "t": .string(g.t), "done": .bool(g.done)]) })
        c["week"] = .string(weekKey())
    }

    /// Ist eine neue Woche angebrochen? Dann alte Woche in den Verlauf (Ziele leeren).
    static func rollOver(_ c: inout [String: JSON]) {
        let now = weekKey()
        guard let old = c["week"]?.string, old != now else { if c["week"] == nil { c["week"] = .string(now) }; return }
        let g = goals(c)
        if !g.isEmpty {
            var h = c["history"]?.array ?? []
            h.insert(.object(["week": .string(old), "done": .number(Double(g.filter { $0.done }.count)),
                              "total": .number(Double(g.count)),
                              "open": .array(g.filter { !$0.done }.map { JSON.string($0.t) })]), at: 0)
            c["history"] = .array(Array(h.prefix(26)))
        }
        c["goals"] = .array([])
        c["week"] = .string(now)
    }

    /// Wochen in Folge mit allen Zielen erreicht
    static func streak(_ c: [String: JSON]) -> Int {
        var n = 0
        for w in history(c) { if w.total > 0 && w.done == w.total { n += 1 } else { break } }
        return n
    }

    static func isCurrent(_ c: [String: JSON]) -> Bool { c["week"]?.string == weekKey() }
}

// MARK: Karte

struct ZieleGlance: View {
    let bucketId: String
    let config: [String: JSON]
    @EnvironmentObject var store: AppStore
    @Environment(\.glanceSpace) private var space

    var body: some View {
        let list = ZieleBucket.isCurrent(config) ? ZieleBucket.goals(config) : []
        if list.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Neue Woche, neue Ziele").font(.headline)
                Text("Was willst du bis Sonntag schaffen? Tipp auf „Alle“.").font(.subheadline).foregroundColor(Theme.secondary)
            }
        } else {
            let done = list.filter { $0.done }.count
            VStack(alignment: .leading, spacing: 6) {
                let rows = fitRows(space.height - 22, row: 32, max: 5)
                ForEach(Array(list.prefix(rows))) { g in
                    Button { toggle(g.id) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: g.done ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundColor(g.done ? Theme.accent : Theme.secondary)
                            Text(g.t).strikethrough(g.done).foregroundColor(g.done ? Theme.secondary : .primary).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .frame(height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Text(done == list.count ? "Alles geschafft 🎉" : "\(done) von \(list.count) · " + ZieleBucket.weekLabel(ZieleBucket.weekKey()))
                    .font(.footnote).foregroundColor(Theme.secondary)
            }
        }
    }

    private func toggle(_ id: String) {
        store.updateConfig(bucketId) { c in
            ZieleBucket.rollOver(&c)
            var g = ZieleBucket.goals(c)
            if let i = g.firstIndex(where: { $0.id == id }) { g[i].done.toggle() }
            ZieleBucket.storeGoals(g, in: &c)
        }
    }
}

// MARK: App

struct ZieleApp: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @State private var newGoal = ""

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        let goals = ZieleBucket.isCurrent(config) ? ZieleBucket.goals(config) : []
        let history = ZieleBucket.history(config)
        let streak = ZieleBucket.streak(config)
        List {
            Section {
                ForEach(goals) { g in
                    Button { change { list in if let i = list.firstIndex(where: { $0.id == g.id }) { list[i].done.toggle() } } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: g.done ? "checkmark.circle.fill" : "circle")
                                .font(.title2).foregroundColor(g.done ? Theme.accent : Theme.secondary)
                            Text(g.t).font(.body).strikethrough(g.done).foregroundColor(g.done ? Theme.secondary : .primary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { idx in let ids = idx.map { goals[$0].id }; change { $0.removeAll { ids.contains($0.id) } } }
                if goals.count < 5 {
                    HStack {
                        TextField(goals.isEmpty ? "Erstes Ziel, z. B. 3× Sport" : "Weiteres Ziel", text: $newGoal)
                            .submitLabel(.done).onSubmit { add() }
                        Button { add() } label: { Image(systemName: "plus.circle.fill") }
                            .disabled(newGoal.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            } header: {
                Text("Diese Woche · " + ZieleBucket.weekLabel(ZieleBucket.weekKey()))
            } footer: {
                Text(goals.count >= 3 ? "Drei Ziele sind ein guter Wert – mehr als fünf geht nicht." : "Tipp: drei konkrete Ziele, die du bis Sonntag schaffen kannst.")
            }

            if goals.isEmpty, let last = history.first, !last.open.isEmpty {
                Section {
                    Button {
                        change { list in list = last.open.map { ZieleBucket.Goal(t: $0) } }
                    } label: { Label("Offene Ziele aus " + ZieleBucket.weekLabel(last.week) + " übernehmen", systemImage: "arrow.uturn.forward") }
                } footer: { Text(last.open.joined(separator: ", ")) }
            }

            if !history.isEmpty {
                Section {
                    if streak > 0 {
                        Label(streak == 1 ? "Letzte Woche alles geschafft" : "\(streak) Wochen in Folge alles geschafft", systemImage: "flame.fill")
                            .foregroundColor(Theme.accent)
                    }
                    ForEach(history) { w in
                        HStack {
                            Text(ZieleBucket.weekLabel(w.week))
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(0..<max(w.total, 1), id: \.self) { i in
                                    Circle().fill(i < w.done ? Theme.accent : Color.gray.opacity(0.25)).frame(width: 10, height: 10)
                                }
                            }
                            Text("\(w.done)/\(w.total)").font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                } header: { Text("Verlauf") }
            }
        }
        .listStyle(.insetGrouped)
        .onAppear { if !ZieleBucket.isCurrent(config) { store.updateConfig(bucketId) { ZieleBucket.rollOver(&$0) } } }
    }

    private func change(_ f: (inout [ZieleBucket.Goal]) -> Void) {
        store.updateConfig(bucketId) { c in
            ZieleBucket.rollOver(&c)
            var g = ZieleBucket.goals(c); f(&g); ZieleBucket.storeGoals(g, in: &c)
        }
    }

    private func add() {
        let s = newGoal.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        change { $0.append(ZieleBucket.Goal(t: s)) }
        newGoal = ""
    }
}
