import SwiftUI

// ============================================================
// Stromverbrauch: Zählerstand eintragen, Verbrauch pro Tag sehen,
// aufs Jahr hochrechnen und mit dem Abschlag vergleichen.
// Einstellungen: readings = [{ d (yyyy-MM-dd), v (kWh) }], price (ct/kWh), base (€/Monat Grundpreis),
//                rate (€/Monat Abschlag)
// ============================================================

enum StromBucket {
    static let kind = BucketKind(
        id: "strom", name: "Stromverbrauch", symbol: "bolt", tint: .yellow, art: .glance,
        interests: ["haushalt"], blurb: "Zählerstand eintragen, Verbrauch pro Tag sehen – und ob der Abschlag reicht.",
        defaultConfig: ["price": .number(32), "base": .number(12)],
        glance: { inst, size in AnyView(StromGlance(config: inst.config)) },
        detail: { inst in AnyView(StromApp(bucketId: inst.id)) },
        settings: { binding in AnyView(StromSettings(config: binding)) }
    )

    struct Reading: Identifiable, Equatable { let date: Date; let value: Double; var id: Date { date } }

    /// Verbrauch zwischen zwei Ablesungen
    struct Span: Identifiable { let from: Date; let to: Date; let kwh: Double; var id: Date { to }
        var days: Double { max(1, to.timeIntervalSince(from) / 86_400) }
        var perDay: Double { kwh / days }
    }

    static func readings(_ c: [String: JSON]) -> [Reading] {
        (c["readings"]?.array ?? []).compactMap { j in
            guard let o = j.object, let d = o["d"]?.string.flatMap({ CountdownBucket.dayFormat.date(from: $0) }),
                  let v = o["v"]?.double else { return nil }
            return Reading(date: d, value: v)
        }
        .sorted { $0.date < $1.date }
    }

    static func store(_ list: [Reading], in c: inout [String: JSON]) {
        c["readings"] = .array(list.sorted { $0.date < $1.date }.map { r in
            JSON.object(["d": .string(CountdownBucket.dayFormat.string(from: r.date)), "v": .number(r.value)])
        })
    }

    static func spans(_ list: [Reading]) -> [Span] {
        guard list.count >= 2 else { return [] }
        return (1..<list.count).compactMap { i in
            let kwh = list[i].value - list[i - 1].value
            return kwh >= 0 ? Span(from: list[i - 1].date, to: list[i].date, kwh: kwh) : nil
        }
    }

    struct Stats { let perDay: Double; let lastPerDay: Double?; let year: Double; let cost: Double; let rateYear: Double? }

    /// Durchschnitt über die letzten 365 Tage (bzw. alles, was da ist)
    static func stats(_ c: [String: JSON]) -> Stats? {
        let list = readings(c)
        guard let last = list.last, list.count >= 2 else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: last.date) ?? last.date
        let first = list.last(where: { $0.date <= cutoff }) ?? list[0]
        let days = max(1, last.date.timeIntervalSince(first.date) / 86_400)
        let perDay = max(0, last.value - first.value) / days
        let year = perDay * 365
        let price = (c["price"]?.double ?? 32) / 100
        let base = c["base"]?.double ?? 0
        let rate = c["rate"]?.double
        return Stats(perDay: perDay, lastPerDay: spans(list).last?.perDay, year: year,
                     cost: year * price + base * 12, rateYear: rate.map { $0 * 12 })
    }

    static func num(_ v: Double, _ digits: Int = 1) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "de_DE"); f.numberStyle = .decimal
        f.minimumFractionDigits = digits; f.maximumFractionDigits = digits
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
    static func euro(_ v: Double) -> String { num(v, 0) + " €" }
}

// MARK: Karte

struct StromGlance: View {
    let config: [String: JSON]
    @Environment(\.glanceSpace) private var space

    var body: some View {
        let list = StromBucket.readings(config)
        if let s = StromBucket.stats(config) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(StromBucket.num(s.perDay)).font(.title.weight(.semibold).monospacedDigit())
                    Text("kWh pro Tag").foregroundColor(Theme.secondary)
                }
                Text("≈ " + StromBucket.num(s.year, 0) + " kWh im Jahr · " + StromBucket.euro(s.cost))
                    .font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1).minimumScaleFactor(0.8)
                if let r = s.rateYear, space.height > 90 {
                    let diff = r - s.cost
                    Text(diff >= 0 ? "Abschlag reicht – ≈ \(StromBucket.euro(diff)) Guthaben" : "≈ \(StromBucket.euro(-diff)) Nachzahlung")
                        .font(.subheadline.weight(.semibold)).foregroundColor(diff >= 0 ? .green : .orange)
                }
                if let last = list.last, space.height > 120 {
                    Text("Zuletzt abgelesen " + StromFmt.ago(last.date)).font(.footnote).foregroundColor(Theme.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.isEmpty ? "Zählerstand eintragen" : "Noch eine Ablesung fehlt").font(.headline)
                Text("Ab zwei Ablesungen rechnet Hubert den Verbrauch aus.").font(.subheadline).foregroundColor(Theme.secondary)
            }
        }
    }
}

enum StromFmt {
    static func ago(_ d: Date) -> String {
        let n = -CountdownBucket.daysLeft(d)
        return n <= 0 ? "heute" : n == 1 ? "gestern" : "vor \(n) Tagen"
    }
    static func date(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "d. MMM yyyy"
        return f.string(from: d)
    }
}

// MARK: App

struct StromApp: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @State private var value = ""
    @State private var date = Date()
    @State private var warning: String?

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        let list = StromBucket.readings(config)
        let spans = StromBucket.spans(list)
        List {
            Section {
                HStack {
                    TextField(list.last.map { "Zuletzt " + StromBucket.num($0.value, 0) } ?? "Zählerstand in kWh", text: $value)
                        .keyboardType(.decimalPad).font(.title3.monospacedDigit())
                    Text("kWh").foregroundColor(Theme.secondary)
                }
                DatePicker("Abgelesen am", selection: $date, in: ...Date(), displayedComponents: .date)
                Button { save() } label: { Label("Zählerstand speichern", systemImage: "bolt.fill") }
                    .disabled(parsed == nil)
                if let w = warning { Text(w).font(.footnote).foregroundColor(.orange) }
            } header: { Text("Ablesen") }

            if let s = StromBucket.stats(config) {
                Section("Verbrauch") {
                    row("Pro Tag (Ø)", StromBucket.num(s.perDay) + " kWh")
                    if let l = s.lastPerDay { row("Seit der letzten Ablesung", StromBucket.num(l) + " kWh/Tag") }
                    row("Hochgerechnet aufs Jahr", StromBucket.num(s.year, 0) + " kWh")
                    row("Kosten im Jahr", StromBucket.euro(s.cost))
                    if let r = s.rateYear {
                        let diff = r - s.cost
                        row(diff >= 0 ? "Voraussichtlich Guthaben" : "Voraussichtlich Nachzahlung", StromBucket.euro(abs(diff)))
                            .foregroundColor(diff >= 0 ? .green : .orange)
                    }
                }
            }

            if spans.count >= 2 {
                Section("kWh pro Tag je Zeitraum") {
                    StromBars(spans: Array(spans.suffix(12))).frame(height: 130).padding(.vertical, 6)
                }
            }

            if !list.isEmpty {
                Section("Ablesungen") {
                    ForEach(Array(list.reversed())) { r in
                        HStack {
                            Text(StromFmt.date(r.date))
                            Spacer()
                            Text(StromBucket.num(r.value, 0) + " kWh").monospacedDigit().foregroundColor(Theme.secondary)
                        }
                    }
                    .onDelete { idx in
                        let rev = Array(list.reversed()); let gone = idx.map { rev[$0].date }
                        store.updateConfig(bucketId) { c in StromBucket.store(StromBucket.readings(c).filter { !gone.contains($0.date) }, in: &c) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var parsed: Double? { Double(value.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")) }

    private func row(_ l: String, _ v: String) -> some View {
        HStack { Text(l); Spacer(); Text(v).monospacedDigit().foregroundColor(Theme.secondary) }
    }

    private func save() {
        guard let v = parsed else { return }
        let day = Calendar.current.startOfDay(for: date)
        let list = StromBucket.readings(config)
        if let before = list.last(where: { $0.date < day }), v < before.value {
            warning = "Der Stand ist kleiner als am \(StromFmt.date(before.date)) – neuer Zähler? Trotzdem gespeichert."
        } else { warning = nil }
        store.updateConfig(bucketId) { c in
            var l = StromBucket.readings(c).filter { !Calendar.current.isDate($0.date, inSameDayAs: day) }
            l.append(StromBucket.Reading(date: day, value: v))
            StromBucket.store(l, in: &c)
        }
        value = ""; date = Date()
    }
}

/// Balken: Verbrauch pro Tag je Zeitraum zwischen zwei Ablesungen
struct StromBars: View {
    let spans: [StromBucket.Span]
    var body: some View {
        let top = max(0.1, spans.map { $0.perDay }.max() ?? 1)
        let f: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "d.M."; return f }()
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(spans) { s in
                VStack(spacing: 4) {
                    Text(StromBucket.num(s.perDay)).font(.system(size: 10).monospacedDigit()).foregroundColor(Theme.secondary)
                    RoundedRectangle(cornerRadius: 4).fill(Color.yellow.opacity(s.id == spans.last?.id ? 1 : 0.6))
                        .frame(height: max(3, CGFloat(s.perDay / top) * 90))
                    Text(f.string(from: s.to)).font(.system(size: 9)).foregroundColor(Theme.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct StromSettings: View {
    @Binding var config: [String: JSON]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("Arbeitspreis", "ct/kWh", "price")
            field("Grundpreis", "€/Monat", "base")
            field("Abschlag", "€/Monat", "rate")
            Text("Mit Abschlag zeigt Hubert, ob am Jahresende Guthaben oder Nachzahlung zu erwarten ist.")
                .font(.footnote).foregroundColor(Theme.secondary)
        }
    }

    private func field(_ title: String, _ unit: String, _ key: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            // Zahl wird beim Bestätigen übernommen; 0 = nicht gesetzt
            TextField("–", value: Binding<Double>(
                get: { config[key]?.double ?? 0 },
                set: { v in config[key] = v > 0 ? .number(v) : nil }),
                      format: .number.locale(Locale(identifier: "de_DE")))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            Text(unit).foregroundColor(Theme.secondary).frame(width: 70, alignment: .leading)
        }
    }
}
