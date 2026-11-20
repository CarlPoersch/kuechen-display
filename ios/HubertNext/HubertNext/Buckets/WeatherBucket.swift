import SwiftUI

// ============================================================
// Wetter-Bucket: beliebiger Ort, Daten von Open-Meteo (frei, ohne Schlüssel).
// Einstellungen: city (Name), lat, lon
// ============================================================
enum WeatherBucket {
    static let kind = BucketKind(
        id: "wetter", name: "Wetter", symbol: "cloud.sun.fill", tint: .blue, art: .glance,
        interests: ["wetter", "unterwegs"], blurb: "Jetzt, heute und die nächsten Tage – mit Regenwarnung.",
        needsSetup: { $0["lat"] == nil },
        glance: { inst, size in AnyView(WeatherGlance(config: inst.config, size: size)) },
        settings: { binding in AnyView(CityPicker(config: binding)) }
    )
}

// MARK: Daten

struct WeatherData: Decodable {
    struct Current: Decodable {
        let temperature2m: Double; let weatherCode: Int; let isDay: Int
        enum CodingKeys: String, CodingKey { case temperature2m = "temperature_2m", weatherCode = "weather_code", isDay = "is_day" }
    }
    struct Daily: Decodable {
        let time: [String]; let weatherCode: [Int]
        let temperature2mMax: [Double]; let temperature2mMin: [Double]
        let precipitationProbabilityMax: [Int?]
        enum CodingKeys: String, CodingKey {
            case time, weatherCode = "weather_code", temperature2mMax = "temperature_2m_max",
                 temperature2mMin = "temperature_2m_min", precipitationProbabilityMax = "precipitation_probability_max"
        }
    }
    struct Hourly: Decodable {
        let time: [String]; let precipitationProbability: [Int?]
        enum CodingKeys: String, CodingKey { case time, precipitationProbability = "precipitation_probability" }
    }
    let current: Current
    let daily: Daily
    let hourly: Hourly
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
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "hourly", value: "precipitation_probability"),
            URLQueryItem(name: "timezone", value: "auto"), URLQueryItem(name: "forecast_days", value: "5"),
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

// MARK: Ansicht auf der Startseite

struct WeatherGlance: View {
    let config: [String: JSON]
    let size: BucketSize
    @ObservedObject private var service = WeatherService.shared

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
            await service.load(lat: lat, lon: lon)
        }
    }

    @ViewBuilder private func content(_ w: WeatherData) -> some View {
        let now = WeatherCode.info(w.current.weatherCode, day: w.current.isDay == 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: now.symbol).renderingMode(.original).font(.system(size: size == .s ? 30 : 38))
                Text("\(Int(w.current.temperature2m.rounded()))°").font(.system(size: size == .s ? 38 : 48, weight: .light))
                Spacer(minLength: 0)
            }
            Text(city).font(.subheadline.weight(.semibold)).lineLimit(1)
            if size != .s {
                Text("\(now.text) · ↑\(Int(w.daily.temperature2mMax.first?.rounded() ?? 0))° ↓\(Int(w.daily.temperature2mMin.first?.rounded() ?? 0))°")
                    .font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                Text(rainHint(w)).font(.subheadline).lineLimit(1)
            }
            if size == .l {
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    ForEach(1..<min(5, w.daily.time.count), id: \.self) { i in
                        VStack(spacing: 4) {
                            Text(weekday(w.daily.time[i])).font(.caption).foregroundColor(Theme.secondary)
                            Image(systemName: WeatherCode.info(w.daily.weatherCode[i]).symbol).renderingMode(.original)
                            Text("\(Int(w.daily.temperature2mMax[i].rounded()))°").font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    /// "Schirm mitnehmen?" – höchste Regenwahrscheinlichkeit in den nächsten 6 Stunden
    private func rainHint(_ w: WeatherData) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let now = Date()
        var best = 0; var at: Date?
        for (i, t) in w.hourly.time.enumerated() {
            guard let d = f.date(from: t), d > now.addingTimeInterval(-3600), d < now.addingTimeInterval(6 * 3600),
                  let p = w.hourly.precipitationProbability[i] else { continue }
            if p > best { best = p; at = d }
        }
        guard best >= 40, let d = at else { return "Kein Regen in Sicht" }
        let h = DateFormatter(); h.dateFormat = "HH:mm"
        return d <= now ? "☂️ Regen \(best) % jetzt" : "☂️ Regen \(best) % gegen \(h.string(from: d))"
    }

    private func weekday(_ iso: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: iso) else { return "" }
        let o = DateFormatter(); o.locale = Locale(identifier: "de_DE"); o.dateFormat = "EE"
        return o.string(from: d)
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
