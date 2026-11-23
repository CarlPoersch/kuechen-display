import SwiftUI
import Combine

// ============================================================
// Reise: nächste Reise mit Countdown, Wetter am Ziel (Vorhersage bzw. Schätzung)
// und Packliste zum Abhaken – nur auf Wunsch, passend zu Ziel, Wetter und Reiseart (ReisePack.swift).
// Reisen erscheinen auch in den Countdowns.
// Einstellungen: trips = [{ id, title, emoji, city, lat, lon, cc (Land), kind (Reiseart), start, end (yyyy-MM-dd),
//                           pack: [{ id, t, done }], packCollapsed }]
// ============================================================

enum ReiseBucket {
    static let kind = BucketKind(
        id: "reise", name: "Reise", symbol: "airplane", tint: .cyan, art: .glance,
        interests: ["unterwegs", "freizeit"], blurb: "Countdown bis zur Reise, Wetter am Ziel und eine Packliste zum Abhaken.",
        glance: { inst, size in AnyView(ReiseGlance(config: inst.config)) },
        detail: { inst in AnyView(ReiseApp(bucketId: inst.id)) }
    )

    struct Item: Identifiable, Equatable { var id = UUID().uuidString.lowercased(); var t: String; var done = false }

    struct Trip: Identifiable, Equatable {
        var id = UUID().uuidString.lowercased()
        var title: String
        var emoji = "✈️"
        var city = ""
        var lat = 0.0, lon = 0.0
        var cc = ""                 // Ländercode, z. B. "TH"
        var kind = ""               // Reiseart (TripKind), leer = nicht gewählt
        var packCollapsed = false
        var start: Date
        var end: Date
        var pack: [Item] = []

        var hasPlace: Bool { !city.isEmpty && (lat != 0 || lon != 0) }
        var upcoming: Bool { CountdownBucket.daysLeft(end) >= 0 }
        var running: Bool { CountdownBucket.daysLeft(start) <= 0 && CountdownBucket.daysLeft(end) >= 0 }
        var nights: Int { max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) }
        var packed: Int { pack.filter { $0.done }.count }
    }

    static func trips(_ c: [String: JSON]) -> [Trip] {
        let f = CountdownBucket.dayFormat
        return (c["trips"]?.array ?? []).compactMap { j in
            guard let o = j.object, let t = o["title"]?.string,
                  let s = o["start"]?.string.flatMap({ f.date(from: $0) }) else { return nil }
            let e = o["end"]?.string.flatMap({ f.date(from: $0) }) ?? s
            let pack: [Item] = (o["pack"]?.array ?? []).compactMap { p in
                guard let po = p.object, let pt = po["t"]?.string else { return nil }
                return Item(id: po["id"]?.string ?? pt, t: pt, done: po["done"]?.bool ?? false)
            }
            return Trip(id: o["id"]?.string ?? t, title: t, emoji: o["emoji"]?.string ?? "✈️",
                        city: o["city"]?.string ?? "", lat: o["lat"]?.double ?? 0, lon: o["lon"]?.double ?? 0,
                        cc: o["cc"]?.string ?? "", kind: o["kind"]?.string ?? "", packCollapsed: o["packCollapsed"]?.bool ?? false,
                        start: s, end: e, pack: pack)
        }
    }

    static func store(_ list: [Trip], in c: inout [String: JSON]) {
        let f = CountdownBucket.dayFormat
        c["trips"] = .array(list.map { t in
            JSON.object(["id": .string(t.id), "title": .string(t.title), "emoji": .string(t.emoji),
                         "city": .string(t.city), "lat": .number(t.lat), "lon": .number(t.lon),
                         "cc": .string(t.cc), "kind": .string(t.kind), "packCollapsed": .bool(t.packCollapsed),
                         "start": .string(f.string(from: t.start)), "end": .string(f.string(from: t.end)),
                         "pack": .array(t.pack.map { i in JSON.object(["id": .string(i.id), "t": .string(i.t), "done": .bool(i.done)]) })])
        })
    }

    /// Reisen aller Reise-Buckets als Countdown-Einträge (Sammelstelle)
    static func countdownEntries(_ store: AppStore) -> [CountdownBucket.Entry] {
        store.buckets.filter { $0.bucket == "reise" }.flatMap { b in
            trips(b.config).map { t in
                CountdownBucket.Entry(id: "reise:" + t.id, title: t.title, date: t.start, emoji: t.emoji, type: .reise, end: t.end)
            }
        }
    }

    static func label(_ t: Trip) -> String {
        if t.running { return "Unterwegs" }
        let d = CountdownBucket.daysLeft(t.start)
        return d == 1 ? "Morgen" : "in \(d) Tagen"
    }

    static func dates(_ t: Trip) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "d. MMM"
        let y = DateFormatter(); y.locale = Locale(identifier: "de_DE"); y.dateFormat = "d. MMM yyyy"
        if Calendar.current.isDate(t.start, inSameDayAs: t.end) { return y.string(from: t.start) }
        return f.string(from: t.start) + " – " + y.string(from: t.end)
    }
}

// MARK: Wetter am Ziel

struct TripWeatherDay: Identifiable {
    let date: Date; let code: Int; let max: Double; let min: Double
    let rain: Int                 // Vorhersage: Regenwahrscheinlichkeit; Schätzung: Anteil der Jahre mit Regen (%)
    var estimated = false
    var id: Date { date }
}

/// Zusammenfassung der Schätzung für die Tage ohne Vorhersage
struct TripClimate { let max: Double; let min: Double; let rainDays: Int; let days: Int; let firstYear: Int; let lastYear: Int }

@MainActor
final class TripWeather: ObservableObject {
    @Published var days: [TripWeatherDay] = []
    @Published var climate: TripClimate?
    @Published var loaded = false
    private var key = ""

    static let horizon = 16          // so weit reicht die Vorhersage von Open-Meteo
    static let years = 5             // so viele vergangene Jahre fließen in die Schätzung ein

    private struct Response: Decodable {
        struct Daily: Decodable {
            let time: [String]; let weather_code: [Int?]
            let temperature_2m_max: [Double?]; let temperature_2m_min: [Double?]
            let precipitation_probability_max: [Int?]?
        }
        let daily: Daily
    }

    private struct Archive: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max: [Double?]; let temperature_2m_min: [Double?]; let precipitation_sum: [Double?]
        }
        let daily: Daily
    }

    /// Vorhersage für Tage in den nächsten 16 Tagen, Schätzung aus vergangenen Jahren für alles danach
    func load(_ t: ReiseBucket.Trip) async {
        let k = "\(t.lat),\(t.lon),\(t.start),\(t.end)"
        guard t.hasPlace, k != key else { loaded = true; return }
        key = k
        defer { loaded = true }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = max(cal.startOfDay(for: t.start), today), to = cal.startOfDay(for: t.end)
        guard from <= to else { days = []; climate = nil; return }
        let lastForecast = cal.date(byAdding: .day, value: Self.horizon - 1, to: today)!

        var out: [TripWeatherDay] = []
        if from <= lastForecast { out = await forecast(t, from: from, to: min(to, lastForecast)) }
        let estFrom = max(from, cal.date(byAdding: .day, value: 1, to: lastForecast)!)
        let estTo = min(to, cal.date(byAdding: .day, value: 30, to: estFrom)!)     // höchstens 31 Tage schätzen
        if estFrom <= estTo {
            let (est, sum) = await estimate(t, from: estFrom, to: estTo)
            out += est; climate = sum
        } else {
            climate = nil
        }
        days = out
    }

    private func forecast(_ t: ReiseBucket.Trip, from: Date, to: Date) async -> [TripWeatherDay] {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [URLQueryItem(name: "latitude", value: String(t.lat)), URLQueryItem(name: "longitude", value: String(t.lon)),
                        URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
                        URLQueryItem(name: "forecast_days", value: String(Self.horizon)), URLQueryItem(name: "timezone", value: "auto")]
        guard let res = try? await URLSession.shared.data(from: c.url!),
              let r = try? JSONDecoder().decode(Response.self, from: res.0) else { return [] }
        let d = r.daily
        var out: [TripWeatherDay] = []
        for (i, s) in d.time.enumerated() {
            guard let day = CountdownBucket.dayFormat.date(from: s), day >= from, day <= to else { continue }
            let rain = d.precipitation_probability_max ?? []
            out.append(TripWeatherDay(date: day, code: (i < d.weather_code.count ? d.weather_code[i] : nil) ?? 0,
                                      max: (i < d.temperature_2m_max.count ? d.temperature_2m_max[i] : nil) ?? 0,
                                      min: (i < d.temperature_2m_min.count ? d.temperature_2m_min[i] : nil) ?? 0,
                                      rain: (i < rain.count ? rain[i] : nil) ?? 0))
        }
        return out
    }

    /// Dieselben Kalendertage der letzten 5 Jahre aus dem Wetterarchiv, je Tag gemittelt
    private func estimate(_ t: ReiseBucket.Trip, from: Date, to: Date) async -> ([TripWeatherDay], TripClimate?) {
        let cal = Calendar.current
        let n = (cal.dateComponents([.day], from: from, to: to).day ?? 0) + 1
        var all: [Archive] = []
        for back in 1...Self.years {
            if let a = await Self.archive(t.lat, t.lon, from, n, back: back) { all.append(a) }
        }
        guard !all.isEmpty else { return ([], nil) }

        var out: [TripWeatherDay] = []
        for i in 0..<n {
            var mx: [Double] = [], mn: [Double] = [], wet = 0, count = 0
            for a in all where i < a.daily.time.count {
                if let v = a.daily.temperature_2m_max[safe: i] ?? nil { mx.append(v) }
                if let v = a.daily.temperature_2m_min[safe: i] ?? nil { mn.append(v) }
                if let p = a.daily.precipitation_sum[safe: i] ?? nil { count += 1; if p >= 1 { wet += 1 } }
            }
            guard !mx.isEmpty, !mn.isEmpty, let day = cal.date(byAdding: .day, value: i, to: from) else { continue }
            let avgMax = mx.reduce(0, +) / Double(mx.count), avgMin = mn.reduce(0, +) / Double(mn.count)
            let share = count > 0 ? Double(wet) / Double(count) : 0
            let code = share >= 0.5 ? (avgMax <= 1 ? 71 : 61) : share >= 0.3 ? 3 : 2
            out.append(TripWeatherDay(date: day, code: code, max: avgMax, min: avgMin, rain: Int((share * 100).rounded()), estimated: true))
        }
        guard !out.isEmpty else { return ([], nil) }
        let year = cal.component(.year, from: from)
        let sum = TripClimate(max: out.map(\.max).reduce(0, +) / Double(out.count),
                              min: out.map(\.min).reduce(0, +) / Double(out.count),
                              rainDays: Int(out.map { Double($0.rain) / 100 }.reduce(0, +).rounded()),
                              days: out.count, firstYear: year - Self.years, lastYear: year - 1)
        return (out, sum)
    }

    private static func archive(_ lat: Double, _ lon: Double, _ from: Date, _ n: Int, back: Int) async -> Archive? {
        let cal = Calendar.current
        guard let s = cal.date(byAdding: .year, value: -back, to: from),
              let e = cal.date(byAdding: .day, value: n - 1, to: s) else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        var c = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")!
        c.queryItems = [URLQueryItem(name: "latitude", value: String(lat)), URLQueryItem(name: "longitude", value: String(lon)),
                        URLQueryItem(name: "start_date", value: f.string(from: s)), URLQueryItem(name: "end_date", value: f.string(from: e)),
                        URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_sum"),
                        URLQueryItem(name: "timezone", value: "auto")]
        guard let res = try? await URLSession.shared.data(from: c.url!) else { return nil }
        return try? JSONDecoder().decode(Archive.self, from: res.0)
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: Karte

struct ReiseGlance: View {
    let config: [String: JSON]
    @Environment(\.glanceSpace) private var space
    @StateObject private var weather = TripWeather()

    /// Kleiner grauer Chip für eine Info
    private func chip<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 5) { content() }
            .font(.footnote.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10).frame(height: 28)
            .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
    }

    var body: some View {
        let next = ReiseBucket.trips(config).filter { $0.upcoming }.sorted { $0.start < $1.start }
        if let t = next.first {
            let d = CountdownBucket.daysLeft(t.start)
            let soon = d <= 7
            VStack(alignment: .leading, spacing: 10) {
                // Kopf: Symbol, Ziel und Daten links – Countdown rechts
                HStack(alignment: .center, spacing: 12) {
                    Text(t.emoji).font(.system(size: 26))
                        .frame(width: 46, height: 46)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.title).font(.headline).lineLimit(1)
                        Text(ReiseBucket.dates(t)).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if t.running || d < 2 {
                        Text(ReiseBucket.label(t)).font(.headline).foregroundColor(Theme.accent)
                    } else {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(d)").font(.system(size: 30, weight: .bold).monospacedDigit())
                                .foregroundColor(soon ? Theme.accent : .primary)
                            Text("Tage").font(.caption).foregroundColor(Theme.secondary)
                        }
                    }
                }
                // Infos als ruhige Chips: Wetter, Packliste
                if space.height > 100 && (weather.days.first != nil || !t.pack.isEmpty) {
                    HStack(spacing: 8) {
                        if let w = weather.days.first {
                            let info = WeatherCode.info(w.code)
                            chip {
                                Image(systemName: info.symbol).renderingMode(.original)
                                Text(w.estimated
                                     ? "meist \(Int((weather.climate?.max ?? w.max).rounded()))°"
                                     : "\(Int(w.max.rounded()))° / \(Int(w.min.rounded()))°").monospacedDigit()
                                if w.estimated { Text("Schätzung").foregroundColor(Theme.secondary) }
                            }
                        }
                        if !t.pack.isEmpty {
                            chip {
                                Image(systemName: t.packed == t.pack.count ? "checkmark.circle.fill" : "suitcase.fill")
                                    .foregroundColor(t.packed == t.pack.count ? .green : Theme.accent)
                                Text("\(t.packed)/\(t.pack.count) gepackt").monospacedDigit()
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                if next.count > 1 && space.height > 160 {
                    Text("Danach: " + next[1].emoji + " " + next[1].title + " · " + ReiseBucket.label(next[1]))
                        .font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
                }
            }
            .task(id: t.id) { await weather.load(t) }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label("Keine Reise geplant", systemImage: "airplane").font(.headline)
                Text("Leg die nächste an – mit Countdown und Wetter am Ziel.").font(.subheadline).foregroundColor(Theme.secondary)
            }
        }
    }
}

// MARK: App

struct ReiseApp: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @State private var newTrip: ReiseBucket.Trip?

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        let all = ReiseBucket.trips(config)
        let coming = all.filter { $0.upcoming }.sorted { $0.start < $1.start }
        let past = all.filter { !$0.upcoming }.sorted { $0.start > $1.start }
        List {
            if all.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch keine Reise").font(.headline)
                        Text("Wohin geht’s? Hubert zählt die Tage, zeigt ab 16 Tagen vorher das Wetter am Ziel und hilft beim Packen.")
                            .font(.subheadline).foregroundColor(Theme.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            if !coming.isEmpty {
                Section("Geplant") {
                    ForEach(coming) { t in
                        NavigationLink { TripView(bucketId: bucketId, tripId: t.id) } label: { row(t) }
                    }
                    .onDelete { idx in remove(idx.map { coming[$0].id }) }
                }
            }
            Section {
                Button { add() } label: { Label("Reise hinzufügen", systemImage: "plus.circle.fill") }
            }
            if !past.isEmpty {
                Section("Vorbei") {
                    ForEach(past) { t in
                        NavigationLink { TripView(bucketId: bucketId, tripId: t.id) } label: { row(t).opacity(0.55) }
                    }
                    .onDelete { idx in remove(idx.map { past[$0].id }) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { add() } label: { Image(systemName: "plus") }.accessibilityLabel("Reise hinzufügen")
            }
        }
        .sheet(item: $newTrip) { t in
            TripEditSheet(trip: t, isNew: true) { saved in
                store.updateConfig(bucketId) { c in
                    var list = ReiseBucket.trips(c); list.append(saved); ReiseBucket.store(list, in: &c)
                }
            }
        }
    }

    private func row(_ t: ReiseBucket.Trip) -> some View {
        HStack(spacing: 12) {
            Text(t.emoji).font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).font(.headline)
                Text(ReiseBucket.dates(t)).font(.subheadline).foregroundColor(Theme.secondary)
            }
            Spacer()
            if t.upcoming {
                Text(ReiseBucket.label(t)).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundColor(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func add() {
        let start = Calendar.current.date(byAdding: .day, value: 14, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        newTrip = ReiseBucket.Trip(title: "", start: start, end: Calendar.current.date(byAdding: .day, value: 3, to: start) ?? start)
    }

    private func remove(_ ids: [String]) {
        store.updateConfig(bucketId) { c in
            ReiseBucket.store(ReiseBucket.trips(c).filter { !ids.contains($0.id) }, in: &c)
        }
    }
}

struct TripView: View {
    let bucketId: String
    let tripId: String
    @EnvironmentObject var store: AppStore
    @StateObject private var weather = TripWeather()
    @State private var editing = false
    @State private var newItem = ""
    @State private var planning = false
    @State private var confirmRemove = false

    private var trip: ReiseBucket.Trip? {
        ReiseBucket.trips(store.buckets.first { $0.id == bucketId }?.config ?? [:]).first { $0.id == tripId }
    }

    var body: some View {
        if let t = trip {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t.emoji).font(.system(size: 44))
                        Text(t.upcoming ? ReiseBucket.label(t) : "Vorbei").font(.system(size: 34, weight: .semibold).monospacedDigit())
                        Text(ReiseBucket.dates(t) + (t.nights > 0 ? " · \(t.nights) Nächte" : "")).foregroundColor(Theme.secondary)
                    }
                    .padding(.vertical, 6)
                }
                if t.hasPlace && t.upcoming {
                    Section {
                        if let c = weather.climate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Schätzung: meist \(Int(c.max.rounded()))° / \(Int(c.min.rounded()))°").font(.headline.monospacedDigit())
                                Text("Regen an etwa \(c.rainDays) von \(c.days) Tagen").font(.subheadline).foregroundColor(Theme.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        if !weather.days.isEmpty {
                            ForEach(weather.days) { d in
                                let info = WeatherCode.info(d.code)
                                HStack {
                                    Text(WeatherFmt.weekday(d.date, long: true)).frame(width: 110, alignment: .leading)
                                    Image(systemName: info.symbol).renderingMode(.original).frame(width: 28)
                                    Text(d.estimated ? "Schätzung" : info.text).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                                    Spacer()
                                    if d.rain >= 30 { Text("\(d.rain) %").font(.caption).foregroundColor(.blue) }
                                    Text((d.estimated ? "~" : "") + "\(Int(d.min.rounded()))° / \(Int(d.max.rounded()))°").monospacedDigit()
                                }
                                .opacity(d.estimated ? 0.75 : 1)
                            }
                        } else if weather.loaded {
                            Text("Wetter gerade nicht erreichbar.").foregroundColor(Theme.secondary)
                        } else {
                            ProgressView()
                        }
                    } header: {
                        Text("Wetter in " + t.city)
                    } footer: {
                        if let c = weather.climate {
                            Text("Tage mit „~“ sind eine Schätzung aus denselben Tagen der Jahre \(String(c.firstYear))–\(String(c.lastYear)). Prozent = in wie vielen dieser Jahre es geregnet hat. Die echte Vorhersage kommt ab \(TripWeather.horizon) Tage vorher.")
                        }
                    }
                }
                if t.pack.isEmpty {
                    // Packliste nur auf Wunsch
                    Section {
                        Button { planning = true } label: {
                            Label("Packliste erstellen", systemImage: "checklist").font(.headline)
                        }
                    } footer: {
                        Text("Hubert schlägt vor, was du brauchst – passend zu Ziel, Wetter, Dauer und Art der Reise.")
                    }
                } else {
                    Section {
                        if !t.packCollapsed {
                            ForEach(t.pack) { i in
                                HStack(spacing: 4) {
                                    Button { toggle(i.id) } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: i.done ? "checkmark.circle.fill" : "circle")
                                                .font(.title3).foregroundColor(i.done ? Theme.accent : Theme.secondary)
                                            Text(i.t).strikethrough(i.done).foregroundColor(i.done ? Theme.secondary : .primary)
                                            Spacer(minLength: 0)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.borderless)
                                    RemoveButton(name: i.t) { change { $0.pack.removeAll { $0.id == i.id } } }
                                }
                            }
                            .onDelete { idx in let ids = idx.map { t.pack[$0].id }; change { $0.pack.removeAll { ids.contains($0.id) } } }
                            HStack {
                                TextField("Etwas hinzufügen", text: $newItem).submitLabel(.done).onSubmit { addItem() }
                                Button { addItem() } label: { Image(systemName: "plus.circle.fill") }
                                    .buttonStyle(.borderless)
                                    .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            Button { planning = true } label: { Label("Vorschläge für diese Reise", systemImage: "sparkles") }
                        }
                    } header: {
                        HStack(spacing: 4) {
                            // Antippen klappt die Packliste ein und aus
                            Button { withAnimation(.easeOut(duration: 0.2)) { change { $0.packCollapsed.toggle() } } } label: {
                                HStack(spacing: 6) {
                                    Text("Packliste · \(t.packed)/\(t.pack.count)")
                                    Image(systemName: t.packCollapsed ? "chevron.down" : "chevron.up").font(.caption.weight(.semibold))
                                    Spacer(minLength: 0)
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(t.packCollapsed ? "Packliste aufklappen" : "Packliste zuklappen")
                            // Alle Aktionen zur Packliste an einer Stelle
                            Menu {
                                Button { planning = true } label: { Label("Vorschläge für diese Reise", systemImage: "sparkles") }
                                if t.packed > 0 {
                                    Button { change { tr in for k in tr.pack.indices { tr.pack[k].done = false } } } label: {
                                        Label("Alle Haken entfernen", systemImage: "arrow.counterclockwise")
                                    }
                                }
                                Divider()
                                Button(role: .destructive) { confirmRemove = true } label: {
                                    Label("Packliste entfernen", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle").font(.title3).foregroundColor(Theme.accent)
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                            .accessibilityLabel("Packliste – weitere Aktionen")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(t.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Bearbeiten") { editing = true } }
            }
            .sheet(isPresented: $editing) {
                TripEditSheet(trip: t, isNew: false) { saved in change { $0 = saved } }
            }
            .sheet(isPresented: $planning) {
                PackPlanSheet(trip: t, days: weather.days) { items in
                    change { tr in tr.pack += items.map { ReiseBucket.Item(t: $0) }; tr.packCollapsed = false }
                }
            }
            .alert("Packliste entfernen?", isPresented: $confirmRemove) {
                Button("Abbrechen", role: .cancel) {}
                Button("Entfernen", role: .destructive) { withAnimation { change { $0.pack = []; $0.packCollapsed = false } } }
            } message: {
                Text("Alle Einträge dieser Reise werden gelöscht. Du kannst jederzeit eine neue erstellen.")
            }
            .task(id: "\(t.lat)\(t.start)\(t.end)") { await weather.load(t) }
        } else {
            Text("Reise nicht gefunden").foregroundColor(Theme.secondary)
        }
    }

    private func change(_ f: (inout ReiseBucket.Trip) -> Void) {
        store.updateConfig(bucketId) { c in
            var list = ReiseBucket.trips(c)
            if let i = list.firstIndex(where: { $0.id == tripId }) { f(&list[i]) }
            ReiseBucket.store(list, in: &c)
        }
    }

    private func toggle(_ id: String) {
        change { t in if let i = t.pack.firstIndex(where: { $0.id == id }) { t.pack[i].done.toggle() } }
    }

    private func addItem() {
        let s = newItem.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        change { $0.pack.append(ReiseBucket.Item(t: s)) }
        newItem = ""
    }
}

struct TripEditSheet: View {
    @State var trip: ReiseBucket.Trip
    let isNew: Bool
    let onSave: (ReiseBucket.Trip) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var place: [String: JSON] = [:]

    private let emojis = ["✈️", "🚆", "🚗", "🏖️", "🏔️", "🏙️", "🎡", "⛷️", "🏕️", "🚢"]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Wohin? z. B. Wien", text: $trip.title)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(emojis, id: \.self) { e in
                                Button { trip.emoji = e } label: {
                                    Text(e).font(.title2).frame(width: 44, height: 44)
                                        .background(Circle().fill(trip.emoji == e ? Theme.accent.opacity(0.18) : Color.clear))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TripKind.allCases) { k in
                                let on = trip.kind == k.rawValue
                                Button { trip.kind = on ? "" : k.rawValue } label: {
                                    Text(k.emoji + " " + k.label).font(.subheadline.weight(.semibold))
                                        .foregroundColor(on ? .white : .primary)
                                        .padding(.horizontal, 14).frame(minHeight: 36)
                                        .background(Capsule().fill(on ? Theme.accent : Color(UIColor.tertiarySystemFill)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: { Text("Art der Reise") } footer: { Text("Hilft bei den Vorschlägen für die Packliste.") }
                Section("Zeitraum") {
                    DatePicker("Hin", selection: $trip.start, displayedComponents: .date)
                    DatePicker("Zurück", selection: $trip.end, in: trip.start..., displayedComponents: .date)
                }
                Section {
                    CityPicker(config: $place)
                } header: { Text("Ziel fürs Wetter") }
            }
            .navigationTitle(isNew ? "Neue Reise" : "Reise bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var t = trip
                        if let c = place["city"]?.string, let la = place["lat"]?.double, let lo = place["lon"]?.double {
                            t.city = c; t.lat = la; t.lon = lo
                            t.cc = place["cc"]?.string ?? (c == trip.city ? trip.cc : "")
                        }
                        if t.title.trimmingCharacters(in: .whitespaces).isEmpty { t.title = t.city.isEmpty ? "Reise" : t.city }
                        if t.end < t.start { t.end = t.start }
                        onSave(t); dismiss()
                    }
                }
            }
            .onAppear {
                if trip.hasPlace { place = ["city": .string(trip.city), "lat": .number(trip.lat), "lon": .number(trip.lon), "cc": .string(trip.cc)] }
            }
        }
        .navigationViewStyle(.stack)
    }
}
