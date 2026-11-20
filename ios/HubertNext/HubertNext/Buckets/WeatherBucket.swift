import SwiftUI
import Combine

// ============================================================
// Wetter-Bucket: beliebiger Ort, Daten von Open-Meteo (frei, ohne Schlüssel).
// Einstellungen: city (Name), lat, lon
// Antippen: ausführliche Ansicht wie Apple Wetter – stündlich, 10 Tage,
// Details, Tag wählen, weitere Orte (pro Gerät gemerkt).
// ============================================================
enum WeatherBucket {
    static let kind = BucketKind(
        id: "wetter", name: "Wetter", symbol: "cloud.sun.fill", tint: .blue, art: .glance,
        interests: ["wetter", "unterwegs"], blurb: "Jetzt, stündlich und 10 Tage – mit Regenwarnung.",
        needsSetup: { $0["lat"] == nil },
        glance: { inst, size in AnyView(WeatherGlance(config: inst.config, size: size)) },
        detail: { inst in AnyView(WeatherDetail(config: inst.config)) },
        settings: { binding in AnyView(CityPicker(config: binding)) }
    )
}

// MARK: Daten

struct WeatherData: Decodable {
    struct Current: Decodable {
        let temp: Double; let feels: Double?; let humidity: Double?; let isDay: Int
        let rain: Double?; let code: Int; let pressure: Double?; let wind: Double?; let windDir: Double?
        enum CodingKeys: String, CodingKey {
            case temp = "temperature_2m", feels = "apparent_temperature", humidity = "relative_humidity_2m",
                 isDay = "is_day", rain = "precipitation", code = "weather_code", pressure = "pressure_msl",
                 wind = "wind_speed_10m", windDir = "wind_direction_10m"
        }
    }
    struct Hourly: Decodable {
        let time: [String]; let temp: [Double?]; let rainProb: [Double?]; let rain: [Double?]
        let code: [Int?]; let isDay: [Int?]
        enum CodingKeys: String, CodingKey {
            case time, temp = "temperature_2m", rainProb = "precipitation_probability", rain = "precipitation",
                 code = "weather_code", isDay = "is_day"
        }
    }
    struct Daily: Decodable {
        let time: [String]; let code: [Int?]; let max: [Double?]; let min: [Double?]
        let sunrise: [String?]; let sunset: [String?]; let uv: [Double?]; let rainSum: [Double?]
        let rainProb: [Double?]; let windMax: [Double?]
        enum CodingKeys: String, CodingKey {
            case time, code = "weather_code", max = "temperature_2m_max", min = "temperature_2m_min",
                 sunrise, sunset, uv = "uv_index_max", rainSum = "precipitation_sum",
                 rainProb = "precipitation_probability_max", windMax = "wind_speed_10m_max"
        }
    }
    let current: Current
    let hourly: Hourly
    let daily: Daily

    struct Hour: Identifiable { let id: Int; let date: Date; let temp: Int; let code: Int; let day: Bool; let rainProb: Int }

    /// Alle Stunden als Liste (Zeiten in Ortszeit)
    var hours: [Hour] {
        hourly.time.indices.compactMap { i in
            guard let d = WeatherFmt.local.date(from: hourly.time[i]) else { return nil }
            return Hour(id: i, date: d, temp: Int((hourly.temp[i] ?? 0).rounded()), code: hourly.code[i] ?? 0,
                        day: (hourly.isDay[i] ?? 1) == 1, rainProb: Int(hourly.rainProb[i] ?? 0))
        }
    }

    func dayDate(_ i: Int) -> Date? { WeatherFmt.day.date(from: daily.time[i]) }
    func maxT(_ i: Int) -> Int { Int((daily.max[i] ?? 0).rounded()) }
    func minT(_ i: Int) -> Int { Int((daily.min[i] ?? 0).rounded()) }
}

enum WeatherFmt {
    static let local: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; return f }()
    static let day: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f }()
    static func weekday(_ d: Date, long: Bool = false) -> String {
        if Calendar.current.isDateInToday(d) { return "Heute" }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = long ? "EEEE" : "EEEEEE"
        return f.string(from: d)
    }
    static func dayShort(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "d.M."; return f.string(from: d)
    }
    static func hour(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH"; return f.string(from: d) + " Uhr"
    }
}

/// Lädt Wetter und merkt es sich 15 Minuten pro Ort (mehrere Buckets mit gleichem Ort laden nur einmal)
final class WeatherService: ObservableObject {
    static let shared = WeatherService()
    @Published private(set) var data: [String: WeatherData] = [:]
    private var loadedAt: [String: Date] = [:]

    static func key(_ lat: Double, _ lon: Double) -> String { String(format: "%.3f,%.3f", lat, lon) }

    func load(lat: Double, lon: Double) async {
        let key = Self.key(lat, lon)
        if let t = loadedAt[key], Date().timeIntervalSince(t) < 15 * 60 { return }
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)), URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,is_day,precipitation,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,precipitation,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max"),
            URLQueryItem(name: "timezone", value: "auto"), URLQueryItem(name: "forecast_days", value: "10"),
        ]
        do {
            let (raw, _) = try await URLSession.shared.data(from: c.url!)
            data[key] = try JSONDecoder().decode(WeatherData.self, from: raw)
            loadedAt[key] = Date()
        } catch {
            print("Wetter:", error)
        }
    }
}

/// Wettercode (WMO) → SF Symbol und Text
enum WeatherCode {
    static func info(_ code: Int, day: Bool = true) -> (symbol: String, text: String) {
        switch code {
        case 0: return (day ? "sun.max.fill" : "moon.stars.fill", "Klar")
        case 1: return (day ? "sun.min.fill" : "moon.fill", "Überwiegend klar")
        case 2: return (day ? "cloud.sun.fill" : "cloud.moon.fill", "Teils bewölkt")
        case 3: return ("cloud.fill", "Bedeckt")
        case 45, 48: return ("cloud.fog.fill", "Nebel")
        case 51, 53, 55, 56, 57: return ("cloud.drizzle.fill", "Niesel")
        case 61, 63, 80, 81: return ("cloud.rain.fill", "Regen")
        case 65, 82: return ("cloud.heavyrain.fill", "Starker Regen")
        case 66, 67: return ("cloud.sleet.fill", "Eisregen")
        case 71, 73, 75, 77, 85, 86: return ("cloud.snow.fill", "Schnee")
        case 95, 96, 99: return ("cloud.bolt.rain.fill", "Gewitter")
        default: return ("thermometer", "")
        }
    }
}

/// "Schirm mitnehmen?" – höchste Regenwahrscheinlichkeit in den nächsten 6 Stunden
func rainHint(_ w: WeatherData) -> String {
    let now = Date()
    let soon = w.hours.filter { $0.date > now.addingTimeInterval(-3600) && $0.date < now.addingTimeInterval(6 * 3600) }
    guard let top = soon.max(by: { $0.rainProb < $1.rainProb }), top.rainProb >= 40 else { return "Kein Regen in Sicht" }
    return top.date <= now ? "☂️ Regen \(top.rainProb) % jetzt" : "☂️ Regen \(top.rainProb) % gegen \(Fmt.hhmm(top.date))"
}

// MARK: Ansicht auf der Startseite

struct WeatherGlance: View {
    let config: [String: JSON]
    let size: BucketSize
    @ObservedObject private var service = WeatherService.shared
    @Environment(\.glanceSpace) private var space

    private var lat: Double? { config["lat"]?.double }
    private var lon: Double? { config["lon"]?.double }
    private var city: String { config["city"]?.string ?? "Ort wählen" }

    var body: some View {
        Group {
            if let lat = lat, let lon = lon {
                if let w = service.data[WeatherService.key(lat, lon)] {
                    content(w)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Text("Ort in den Einstellungen wählen").foregroundColor(Theme.secondary)
            }
        }
        .task(id: "\(lat ?? 0),\(lon ?? 0)") {
            guard let lat = lat, let lon = lon else { return }
            while !Task.isCancelled {   // alle 15 min neu
                await service.load(lat: lat, lon: lon)
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
            }
        }
    }

    /// Was zusätzlich in die Karte passt, je nach Platz:
    /// klein = jetzt · mittel = + nächste Tage · groß = + stündlich
    @ViewBuilder private func content(_ w: WeatherData) -> some View {
        let now = WeatherCode.info(w.current.code, day: w.current.isDay == 1)
        let wide = space.width >= 260
        let big: CGFloat = space.height > 200 ? 52 : 40
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: now.symbol).renderingMode(.original).font(.system(size: big * 0.8))
                Text("\(Int(w.current.temp.rounded()))°").font(.system(size: big, weight: .light))
                Spacer(minLength: 0)
                if wide {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(city).font(.headline).lineLimit(1)
                        Text(now.text).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                        Text("↑\(w.maxT(0))° ↓\(w.minT(0))°").font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary)
                    }
                }
            }
            if !wide {
                Text(city).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(now.text) · ↑\(w.maxT(0))° ↓\(w.minT(0))°").font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
            }
            if space.height > 120 {
                Text(rainHint(w)).font(.subheadline).lineLimit(1)
            }
            Spacer(minLength: 0)
            if wide && space.height > 250 {
                hourStrip(w, count: space.width > 500 ? 10 : 6)
                Divider()
            }
            if wide && space.height > 140 {
                dayStrip(w, count: space.width > 500 ? 7 : 5)
            } else if !wide && space.height > 170 {
                // Schmal, aber hoch: die nächsten Tage als Zeilen
                ForEach(1..<min(Int((space.height - 110) / 24) + 1, w.daily.time.count), id: \.self) { i in
                    HStack {
                        Text(w.dayDate(i).map { WeatherFmt.weekday($0) } ?? "").font(.subheadline).frame(width: 28, alignment: .leading)
                        Image(systemName: WeatherCode.info(w.daily.code[i] ?? 0).symbol).renderingMode(.original)
                        Spacer()
                        Text("\(w.maxT(i))° / \(w.minT(i))°").font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
    }

    private func hourStrip(_ w: WeatherData, count: Int) -> some View {
        let next = Array(w.hours.filter { $0.date > Date().addingTimeInterval(-3600) }.prefix(count))
        return HStack(spacing: 0) {
            ForEach(next) { h in
                VStack(spacing: 4) {
                    Text(h.id == next.first?.id ? "Jetzt" : String(Fmt.hhmm(h.date).prefix(2))).font(.caption).foregroundColor(Theme.secondary)
                    Image(systemName: WeatherCode.info(h.code, day: h.day).symbol).renderingMode(.original).frame(height: 20)
                    Text("\(h.temp)°").font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayStrip(_ w: WeatherData, count: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(1..<min(count + 1, w.daily.time.count), id: \.self) { i in
                VStack(spacing: 4) {
                    Text(w.dayDate(i).map { WeatherFmt.weekday($0) } ?? "").font(.caption).foregroundColor(Theme.secondary)
                    Image(systemName: WeatherCode.info(w.daily.code[i] ?? 0).symbol).renderingMode(.original).frame(height: 20)
                    Text("\(w.maxT(i))°").font(.subheadline.weight(.semibold)) + Text(" \(w.minT(i))°").font(.caption).foregroundColor(Theme.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: Ausführliche Ansicht (wie Apple Wetter)

struct WeatherPlace: Codable, Equatable, Hashable { let n: String; let lat: Double; let lon: Double }

struct WeatherDetail: View {
    let config: [String: JSON]
    @ObservedObject private var service = WeatherService.shared
    /// Weitere Orte, nur auf diesem Gerät gemerkt
    @AppStorage("weather.places") private var extraRaw = ""
    @State private var place: WeatherPlace?
    @State private var day = 0
    @State private var adding = false
    @State private var newPlace: [String: JSON] = [:]

    private var home: WeatherPlace? {
        guard let lat = config["lat"]?.double, let lon = config["lon"]?.double else { return nil }
        return WeatherPlace(n: config["city"]?.string ?? "Ort", lat: lat, lon: lon)
    }
    private var extras: [WeatherPlace] { (try? JSONDecoder().decode([WeatherPlace].self, from: Data(extraRaw.utf8))) ?? [] }
    private func saveExtras(_ l: [WeatherPlace]) {
        extraRaw = String(data: (try? JSONEncoder().encode(l)) ?? Data(), encoding: .utf8) ?? ""
    }
    private var places: [WeatherPlace] { [home].compactMap { $0 } + extras.filter { $0 != home } }
    private var current: WeatherPlace? { place ?? places.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                placeChips
                if let p = current, let w = service.data[WeatherService.key(p.lat, p.lon)] {
                    hero(p, w)
                    daySelector(w)
                    card("STÜNDLICH", "clock") { hourly(w) }
                    card("10-TAGE-VORHERSAGE", "calendar") { tenDays(w) }
                    details(w)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                }
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .task(id: current) {
            guard let p = current else { return }
            await service.load(lat: p.lat, lon: p.lon)
        }
        .sheet(isPresented: $adding) {
            NavigationView {
                Form { CityPicker(config: $newPlace) }
                    .navigationTitle("Ort hinzufügen").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { adding = false } } }
            }
            .navigationViewStyle(.stack)
        }
        .onChange(of: newPlace) { c in
            guard let lat = c["lat"]?.double, let lon = c["lon"]?.double else { return }
            let p = WeatherPlace(n: c["city"]?.string ?? "Ort", lat: lat, lon: lon)
            saveExtras(extras.filter { $0 != p } + [p])
            place = p; day = 0; newPlace = [:]; adding = false
        }
    }

    // Orte als Kapseln, "+" fügt einen hinzu, lange drücken entfernt
    private var placeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(places, id: \.self) { p in
                    let on = p == current
                    Button { place = p; day = 0 } label: {
                        Label(p.n, systemImage: p == home ? "location.fill" : "mappin")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .foregroundColor(on ? .white : Theme.accent)
                            .background(Capsule().fill(on ? Theme.accent : Color(UIColor.tertiarySystemFill)))
                    }
                    .contextMenu {
                        if p != home {
                            Button(role: .destructive) {
                                saveExtras(extras.filter { $0 != p }); if place == p { place = nil }
                            } label: { Label("Ort entfernen", systemImage: "trash") }
                        }
                    }
                }
                Button { adding = true } label: {
                    Image(systemName: "plus").font(.subheadline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                }
                .accessibilityLabel("Ort hinzufügen")
            }
        }
    }

    private func hero(_ p: WeatherPlace, _ w: WeatherData) -> some View {
        let today = day == 0
        let code = today ? w.current.code : (w.daily.code[day] ?? 0)
        let info = WeatherCode.info(code, day: today ? w.current.isDay == 1 : true)
        return VStack(spacing: 4) {
            Text(p.n).font(.title2.weight(.semibold))
            if today {
                Text("\(Int(w.current.temp.rounded()))°").font(.system(size: 84, weight: .thin))
            } else {
                Text(w.dayDate(day).map { WeatherFmt.weekday($0, long: true) + ", " + WeatherFmt.dayShort($0) } ?? "")
                    .font(.title3).foregroundColor(Theme.secondary)
                Image(systemName: info.symbol).renderingMode(.original).font(.system(size: 56)).padding(.vertical, 6)
            }
            Text(info.text).font(.title3)
            Text("H: \(w.maxT(day))°  T: \(w.minT(day))°").font(.headline.monospacedDigit())
            if today { Text(rainHint(w)).font(.subheadline).foregroundColor(Theme.secondary) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func daySelector(_ w: WeatherData) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(w.daily.time.indices, id: \.self) { i in
                    let on = i == day
                    Button { day = i } label: {
                        VStack(spacing: 4) {
                            Text(w.dayDate(i).map { WeatherFmt.weekday($0) } ?? "").font(.caption.weight(.semibold))
                            Text(w.dayDate(i).map { WeatherFmt.dayShort($0) } ?? "").font(.caption2)
                            Image(systemName: WeatherCode.info(w.daily.code[i] ?? 0).symbol).renderingMode(.original)
                            Text("\(w.maxT(i))°").font(.subheadline.weight(.semibold))
                        }
                        .frame(width: 58).padding(.vertical, 10)
                        .foregroundColor(on ? .white : .primary)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Theme.accent : Theme.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func card<C: View>(_ title: String, _ symbol: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
            c()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
    }

    /// Stunden des gewählten Tags (heute: ab jetzt, 24 Stunden)
    private func hourly(_ w: WeatherData) -> some View {
        let all = w.hours
        let list: [WeatherData.Hour]
        if day == 0 {
            list = Array(all.filter { $0.date > Date().addingTimeInterval(-3600) }.prefix(25))
        } else if let d = w.dayDate(day) {
            list = all.filter { Calendar.current.isDate($0.date, inSameDayAs: d) }
        } else { list = [] }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(list) { h in
                    VStack(spacing: 6) {
                        Text(day == 0 && h.id == list.first?.id ? "Jetzt" : String(Fmt.hhmm(h.date).prefix(2)))
                            .font(.subheadline.weight(.medium))
                        Image(systemName: WeatherCode.info(h.code, day: h.day).symbol).renderingMode(.original)
                            .font(.title3).frame(height: 26)
                        Text(h.rainProb >= 20 ? "\(h.rainProb) %" : " ").font(.caption2.weight(.semibold)).foregroundColor(.blue)
                        Text("\(h.temp)°").font(.headline)
                    }
                }
            }
        }
    }

    private func tenDays(_ w: WeatherData) -> some View {
        let lo = w.daily.min.compactMap { $0 }.min() ?? 0
        let hi = w.daily.max.compactMap { $0 }.max() ?? 1
        return VStack(spacing: 0) {
            ForEach(w.daily.time.indices, id: \.self) { i in
                if i > 0 { Divider() }
                Button { day = i } label: {
                    HStack(spacing: 12) {
                        Text(w.dayDate(i).map { WeatherFmt.weekday($0) } ?? "").font(.headline)
                            .frame(width: 54, alignment: .leading)
                        VStack(spacing: 0) {
                            Image(systemName: WeatherCode.info(w.daily.code[i] ?? 0).symbol).renderingMode(.original)
                            if let p = w.daily.rainProb[i], p >= 20 { Text("\(Int(p)) %").font(.caption2.weight(.semibold)).foregroundColor(.blue) }
                        }
                        .frame(width: 40)
                        Text("\(w.minT(i))°").foregroundColor(Theme.secondary).frame(width: 36, alignment: .trailing)
                        RangeBar(lo: lo, hi: hi, from: w.daily.min[i] ?? lo, to: w.daily.max[i] ?? hi)
                        Text("\(w.maxT(i))°").fontWeight(.semibold).frame(width: 36, alignment: .leading)
                    }
                    .padding(.vertical, 9)
                    .background(i == day ? Theme.accent.opacity(0.08) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func details(_ w: WeatherData) -> some View {
        let today = day == 0
        var tiles: [(String, String, String, String)] = []   // Titel, Symbol, Wert, Zusatz
        if today, let f = w.current.feels {
            tiles.append(("GEFÜHLT", "thermometer.medium", "\(Int(f.rounded()))°", f < w.current.temp - 1 ? "Wind macht es kälter" : "Wie gemessen"))
        }
        let wind = today ? w.current.wind : w.daily.windMax[day]
        if let v = wind {
            tiles.append(("WIND", "wind", "\(Int(v.rounded())) km/h", today ? compass(w.current.windDir) : "Spitze am Tag"))
        }
        if today, let h = w.current.humidity { tiles.append(("LUFTFEUCHTIGKEIT", "humidity", "\(Int(h)) %", "")) }
        if let uv = w.daily.uv[day] { tiles.append(("UV-INDEX", "sun.max", "\(Int(uv.rounded()))", uvText(uv))) }
        if let r = w.daily.rainSum[day] {
            tiles.append(("NIEDERSCHLAG", "drop.fill", String(format: "%.1f mm", r), today ? "heute insgesamt" : "am Tag"))
        }
        if let s = w.daily.sunrise[day].flatMap({ WeatherFmt.local.date(from: $0) }) {
            let set = w.daily.sunset[day].flatMap { WeatherFmt.local.date(from: $0) }
            tiles.append(("SONNE", "sunrise.fill", Fmt.hhmm(s), set.map { "Untergang " + Fmt.hhmm($0) } ?? ""))
        }
        if today, let p = w.current.pressure { tiles.append(("LUFTDRUCK", "gauge", "\(Int(p.rounded())) hPa", "")) }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            ForEach(tiles, id: \.0) { t in
                VStack(alignment: .leading, spacing: 6) {
                    Label(t.0, systemImage: t.1).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                    Text(t.2).font(.system(size: 30, weight: .medium)).lineLimit(1).minimumScaleFactor(0.6)
                    Text(t.3).font(.footnote).foregroundColor(Theme.secondary).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
            }
        }
    }

    private func compass(_ deg: Double?) -> String {
        guard let d = deg else { return "" }
        let dirs = ["Nord", "Nordost", "Ost", "Südost", "Süd", "Südwest", "West", "Nordwest"]
        return "aus " + dirs[Int((d + 22.5) / 45) % 8]
    }
    private func uvText(_ uv: Double) -> String {
        uv < 3 ? "Niedrig" : uv < 6 ? "Mäßig" : uv < 8 ? "Hoch" : uv < 11 ? "Sehr hoch" : "Extrem"
    }
}

/// Temperaturspanne eines Tages im Verhältnis zur ganzen Woche
struct RangeBar: View {
    let lo: Double; let hi: Double; let from: Double; let to: Double
    var body: some View {
        GeometryReader { g in
            let span = max(hi - lo, 1)
            let x0 = CGFloat((from - lo) / span) * g.size.width
            let x1 = CGFloat((to - lo) / span) * g.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color(UIColor.tertiarySystemFill))
                Capsule().fill(LinearGradient(colors: [.cyan, .green, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(x1 - x0, 6)).offset(x: x0)
            }
        }
        .frame(height: 5)
    }
}

// MARK: Ort suchen (Einstellung)

struct CityPicker: View {
    @Binding var config: [String: JSON]
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var searching = false

    struct Place: Decodable, Identifiable {
        let id: Int; let name: String; let latitude: Double; let longitude: Double
        let admin1: String?; let country: String?
    }
    private struct Response: Decodable { let results: [Place]? }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let city = config["city"]?.string {
                Label(city, systemImage: "mappin.circle.fill").font(.headline)
            }
            HStack {
                TextField("Stadt suchen, z. B. Regensburg", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                Button("Suchen") { Task { await search() } }.disabled(query.count < 2)
            }
            if searching { ProgressView() }
            ForEach(results) { p in
                Button {
                    config["city"] = .string(p.name)
                    config["lat"] = .number(p.latitude)
                    config["lon"] = .number(p.longitude)
                    results = []; query = ""
                } label: {
                    VStack(alignment: .leading) {
                        Text(p.name).foregroundColor(.primary)
                        Text([p.admin1, p.country].compactMap { $0 }.joined(separator: ", "))
                            .font(.caption).foregroundColor(Theme.secondary)
                    }
                }
            }
        }
    }

    private func search() async {
        searching = true
        defer { searching = false }
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [URLQueryItem(name: "name", value: query), URLQueryItem(name: "count", value: "6"),
                        URLQueryItem(name: "language", value: "de")]
        guard let res = try? await URLSession.shared.data(from: c.url!),
              let r = try? JSONDecoder().decode(Response.self, from: res.0) else { results = []; return }
        results = r.results ?? []
    }
}
