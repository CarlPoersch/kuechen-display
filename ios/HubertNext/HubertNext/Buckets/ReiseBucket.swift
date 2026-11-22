import SwiftUI
import Combine

// ============================================================
// Reise: nächste Reise mit Countdown, Wetter am Ziel (ab 16 Tage vorher)
// und Packliste zum Abhaken. Reisen erscheinen auch in den Countdowns.
// Einstellungen: trips = [{ id, title, emoji, city, lat, lon, start, end (yyyy-MM-dd),
//                           pack: [{ id, t, done }] }]
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
        var start: Date
        var end: Date
        var pack: [Item] = []

        var hasPlace: Bool { !city.isEmpty && (lat != 0 || lon != 0) }
        var upcoming: Bool { CountdownBucket.daysLeft(end) >= 0 }
        var running: Bool { CountdownBucket.daysLeft(start) <= 0 && CountdownBucket.daysLeft(end) >= 0 }
        var nights: Int { max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) }
        var packed: Int { pack.filter { $0.done }.count }
    }

    static let defaultPack = ["Ausweis", "Tickets / Buchungen", "Geldbeutel & Karten", "Handy-Ladekabel", "Powerbank",
                              "Kopfhörer", "Zahnbürste & Zahnpasta", "Duschzeug", "Unterwäsche & Socken", "T-Shirts",
                              "Pulli / Jacke", "Schlafsachen", "Medikamente", "Schlüssel"]

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
                        start: s, end: e, pack: pack)
        }
    }

    static func store(_ list: [Trip], in c: inout [String: JSON]) {
        let f = CountdownBucket.dayFormat
        c["trips"] = .array(list.map { t in
            JSON.object(["id": .string(t.id), "title": .string(t.title), "emoji": .string(t.emoji),
                         "city": .string(t.city), "lat": .number(t.lat), "lon": .number(t.lon),
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

struct TripWeatherDay: Identifiable { let date: Date; let code: Int; let max: Double; let min: Double; let rain: Int; var id: Date { date } }

@MainActor
final class TripWeather: ObservableObject {
    @Published var days: [TripWeatherDay] = []
    @Published var loaded = false
    private var key = ""

    private struct Response: Decodable {
        struct Daily: Decodable {
            let time: [String]; let weather_code: [Int?]
            let temperature_2m_max: [Double?]; let temperature_2m_min: [Double?]
            let precipitation_probability_max: [Int?]?
        }
        let daily: Daily
    }

    /// Lädt nur, wenn die Reise in den nächsten 16 Tagen beginnt (weiter reicht keine Vorhersage)
    func load(_ t: ReiseBucket.Trip) async {
        let k = "\(t.lat),\(t.lon),\(t.start),\(t.end)"
        guard t.hasPlace, k != key, CountdownBucket.daysLeft(t.start) < 16 else { loaded = true; return }
        key = k
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [URLQueryItem(name: "latitude", value: String(t.lat)), URLQueryItem(name: "longitude", value: String(t.lon)),
                        URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
                        URLQueryItem(name: "forecast_days", value: "16"), URLQueryItem(name: "timezone", value: "auto")]
        defer { loaded = true }
        guard let res = try? await URLSession.shared.data(from: c.url!),
              let r = try? JSONDecoder().decode(Response.self, from: res.0) else { return }
        let d = r.daily
        let from = Calendar.current.startOfDay(for: t.start), to = Calendar.current.startOfDay(for: t.end)
        var out: [TripWeatherDay] = []
        for (i, s) in d.time.enumerated() {
            guard let day = CountdownBucket.dayFormat.date(from: s), day >= from, day <= to else { continue }
            let rain = d.precipitation_probability_max ?? []
            out.append(TripWeatherDay(date: day, code: (i < d.weather_code.count ? d.weather_code[i] : nil) ?? 0,
                                      max: (i < d.temperature_2m_max.count ? d.temperature_2m_max[i] : nil) ?? 0,
                                      min: (i < d.temperature_2m_min.count ? d.temperature_2m_min[i] : nil) ?? 0,
                                      rain: (i < rain.count ? rain[i] : nil) ?? 0))
        }
        days = out
    }
}

// MARK: Karte

struct ReiseGlance: View {
    let config: [String: JSON]
    @Environment(\.glanceSpace) private var space
    @StateObject private var weather = TripWeather()

    var body: some View {
        let next = ReiseBucket.trips(config).filter { $0.upcoming }.sorted { $0.start < $1.start }
        if let t = next.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(t.emoji).font(.title2)
                    Text(ReiseBucket.label(t)).font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundColor(CountdownBucket.daysLeft(t.start) <= 7 ? Theme.accent : .primary)
                    Spacer(minLength: 0)
                    if let w = weather.days.first {
                        let info = WeatherCode.info(w.code)
                        Image(systemName: info.symbol).renderingMode(.original)
                        Text("\(Int(w.max.rounded()))°").font(.headline.monospacedDigit())
                    }
                }
                Text(t.title + (t.city.isEmpty || t.city == t.title ? "" : " · " + t.city)).font(.headline).lineLimit(1)
                Text(ReiseBucket.dates(t)).font(.subheadline).foregroundColor(Theme.secondary)
                if !t.pack.isEmpty && space.height > 100 {
                    HStack(spacing: 8) {
                        ProgressView(value: Double(t.packed), total: Double(max(1, t.pack.count))).tint(Theme.accent)
                        Text("Gepackt \(t.packed)/\(t.pack.count)").font(.caption.monospacedDigit()).foregroundColor(Theme.secondary)
                    }
                    .padding(.top, 4)
                }
                if next.count > 1 && space.height > 150 {
                    Text("Danach: " + next[1].emoji + " " + next[1].title + " · " + ReiseBucket.label(next[1]))
                        .font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
                }
            }
            .task(id: t.id) { await weather.load(t) }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keine Reise geplant").font(.headline)
                Text("Leg die nächste an – mit Wetter am Ziel und Packliste.").font(.subheadline).foregroundColor(Theme.secondary)
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
        newTrip = ReiseBucket.Trip(title: "", start: start, end: Calendar.current.date(byAdding: .day, value: 3, to: start) ?? start,
                                   pack: ReiseBucket.defaultPack.map { ReiseBucket.Item(t: $0) })
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
                    Section("Wetter in " + t.city) {
                        if !weather.days.isEmpty {
                            ForEach(weather.days) { d in
                                let info = WeatherCode.info(d.code)
                                HStack {
                                    Text(WeatherFmt.weekday(d.date, long: true)).frame(width: 110, alignment: .leading)
                                    Image(systemName: info.symbol).renderingMode(.original).frame(width: 28)
                                    Text(info.text).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                                    Spacer()
                                    if d.rain >= 30 { Text("\(d.rain) %").font(.caption).foregroundColor(.blue) }
                                    Text("\(Int(d.min.rounded()))° / \(Int(d.max.rounded()))°").monospacedDigit()
                                }
                            }
                        } else if weather.loaded {
                            Text(CountdownBucket.daysLeft(t.start) >= 16
                                 ? "Die Vorhersage gibt es ab 16 Tage vor der Abreise."
                                 : "Wetter gerade nicht erreichbar.")
                                .foregroundColor(Theme.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                }
                Section {
                    ForEach(t.pack) { i in
                        Button { toggle(i.id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: i.done ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundColor(i.done ? Theme.accent : Theme.secondary)
                                Text(i.t).strikethrough(i.done).foregroundColor(i.done ? Theme.secondary : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { idx in let ids = idx.map { t.pack[$0].id }; change { $0.pack.removeAll { ids.contains($0.id) } } }
                    HStack {
                        TextField("Etwas hinzufügen", text: $newItem).submitLabel(.done).onSubmit { addItem() }
                        Button { addItem() } label: { Image(systemName: "plus.circle.fill") }.disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Packliste · \(t.packed)/\(t.pack.count)")
                } footer: {
                    if t.packed > 0 {
                        Button("Alle Haken entfernen") { change { tr in for k in tr.pack.indices { tr.pack[k].done = false } } }
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
                        }
                        if t.title.trimmingCharacters(in: .whitespaces).isEmpty { t.title = t.city.isEmpty ? "Reise" : t.city }
                        if t.end < t.start { t.end = t.start }
                        onSave(t); dismiss()
                    }
                }
            }
            .onAppear {
                if trip.hasPlace { place = ["city": .string(trip.city), "lat": .number(trip.lat), "lon": .number(trip.lon)] }
            }
        }
        .navigationViewStyle(.stack)
    }
}
