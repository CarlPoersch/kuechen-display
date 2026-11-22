import SwiftUI
import Combine

// ============================================================
// Pollen & UV: Pollenflug (Erle, Birke, Gräser, Beifuß, Ambrosia) für heute
// und die nächsten Tage, dazu der UV-Index über den Tag.
// Daten: Open-Meteo Luftqualität (Copernicus CAMS, Europa), ohne Schlüssel.
// Einstellungen: city, lat, lon (Standard Regensburg), types = gezeigte Pollenarten
// ============================================================

enum PollenBucket {
    static let kind = BucketKind(
        id: "pollen", name: "Pollen & UV", symbol: "allergens", tint: .yellow, art: .glance,
        interests: ["wetter", "gesundheit"], blurb: "Pollenflug für heute und die nächsten Tage, dazu der UV-Index – mit Tipp, ab wann Sonnencreme nötig ist.",
        defaultConfig: ["city": .string("Regensburg"), "lat": .number(49.0134), "lon": .number(12.1016)],
        glance: { inst, size in AnyView(PollenGlance(config: inst.config)) },
        detail: { inst in AnyView(PollenDetail(config: inst.config)) },
        settings: { binding in AnyView(PollenSettings(config: binding)) }
    )

    /// Pollenart mit Schwellen (Körner/m³) für gering / mittel / stark
    struct Kind: Identifiable, Hashable {
        let id: String; let name: String; let months: String
        let low: Double; let high: Double
        func level(_ v: Double) -> Int { v < 1 ? 0 : v <= low ? 1 : v <= high ? 2 : 3 }
    }

    static let kinds: [Kind] = [
        Kind(id: "alder", name: "Erle", months: "Jan–Apr", low: 10, high: 100),
        Kind(id: "birch", name: "Birke", months: "Mär–Mai", low: 10, high: 100),
        Kind(id: "grass", name: "Gräser", months: "Mai–Aug", low: 10, high: 50),
        Kind(id: "mugwort", name: "Beifuß", months: "Jul–Sep", low: 5, high: 30),
        Kind(id: "ragweed", name: "Ambrosia", months: "Aug–Okt", low: 5, high: 30),
    ]

    /// Gezeigte Arten (leer = alle)
    static func shown(_ c: [String: JSON]) -> [Kind] {
        let ids = (c["types"]?.array ?? []).compactMap { $0.string }
        return ids.isEmpty ? kinds : kinds.filter { ids.contains($0.id) }
    }

    static let levelNames = ["Keine", "Gering", "Mittel", "Stark"]
    static func levelColor(_ l: Int) -> Color { [Color.gray.opacity(0.35), .green, .orange, .red][max(0, min(3, l))] }

    /// UV-Stufe nach WHO
    static func uvInfo(_ uv: Double) -> (text: String, color: Color, tip: String) {
        switch uv {
        case ..<3: return ("Niedrig", .green, "Kein Sonnenschutz nötig.")
        case ..<6: return ("Mäßig", .yellow, "Mittags Schatten, Sonnencreme ab LSF 30.")
        case ..<8: return ("Hoch", .orange, "Sonnencreme, Hut und Sonnenbrille – mittags Schatten suchen.")
        case ..<11: return ("Sehr hoch", .red, "Mittags möglichst drinnen bleiben.")
        default: return ("Extrem", .purple, "Ungeschützt nicht in die Sonne.")
        }
    }
}

// MARK: Daten

struct PollenDay: Identifiable {
    let date: Date
    var id: Date { date }
    var levels: [String: Double]     // Höchstwert des Tages je Art
    var uvMax: Double
    var uvHours: [UVHour]
}

struct UVHour: Hashable { let hour: Int; let uv: Double }

@MainActor
final class PollenModel: ObservableObject {
    @Published var days: [PollenDay] = []
    @Published var failed = false
    @Published var loading = false
    private var key = ""
    private var loadedAt = Date.distantPast

    /// Ein Modell je Ort, damit Karte und App dieselben Daten teilen
    private static var shared: [String: PollenModel] = [:]
    static func model(lat: Double, lon: Double) -> PollenModel {
        let k = String(format: "%.2f,%.2f", lat, lon)
        if let m = shared[k] { return m }
        let m = PollenModel(); m.key = k; shared[k] = m; return m
    }

    private struct Response: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let uv_index: [Double?]?
            let alder_pollen: [Double?]?, birch_pollen: [Double?]?, grass_pollen: [Double?]?
            let mugwort_pollen: [Double?]?, ragweed_pollen: [Double?]?
        }
        let hourly: Hourly
    }

    func load(lat: Double, lon: Double) async {
        guard Date().timeIntervalSince(loadedAt) > 1800, !loading else { return }
        loading = true; defer { loading = false }
        var c = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        c.queryItems = [URLQueryItem(name: "latitude", value: String(lat)), URLQueryItem(name: "longitude", value: String(lon)),
                        URLQueryItem(name: "hourly", value: "uv_index,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,ragweed_pollen"),
                        URLQueryItem(name: "forecast_days", value: "4"), URLQueryItem(name: "timezone", value: "auto")]
        guard let res = try? await URLSession.shared.data(from: c.url!),
              let r = try? JSONDecoder().decode(Response.self, from: res.0) else { failed = days.isEmpty; return }
        let h = r.hourly
        let series: [String: [Double?]] = ["alder": h.alder_pollen ?? [], "birch": h.birch_pollen ?? [], "grass": h.grass_pollen ?? [],
                                           "mugwort": h.mugwort_pollen ?? [], "ragweed": h.ragweed_pollen ?? []]
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        var out: [String: PollenDay] = [:]
        var order: [String] = []
        for (i, t) in h.time.enumerated() {
            let dayKey = String(t.prefix(10))
            guard let d = f.date(from: t) else { continue }
            if out[dayKey] == nil {
                out[dayKey] = PollenDay(date: Calendar.current.startOfDay(for: d), levels: [:], uvMax: 0, uvHours: [])
                order.append(dayKey)
            }
            let hour = Calendar.current.component(.hour, from: d)
            let uvList = h.uv_index ?? []
            let uv = i < uvList.count ? (uvList[i] ?? 0) : 0
            out[dayKey]?.uvMax = max(out[dayKey]?.uvMax ?? 0, uv)
            out[dayKey]?.uvHours.append(UVHour(hour: hour, uv: uv))
            for (k, list) in series where i < list.count {
                let v = list[i] ?? 0
                out[dayKey]?.levels[k] = max(out[dayKey]?.levels[k] ?? 0, v)
            }
        }
        days = order.compactMap { out[$0] }
        failed = days.isEmpty
        loadedAt = Date()
    }

    /// UV-Index jetzt (aus der aktuellen Stunde)
    var uvNow: Double {
        guard let today = days.first else { return 0 }
        let hour = Calendar.current.component(.hour, from: Date())
        return today.uvHours.first { $0.hour == hour }?.uv ?? 0
    }
}

// MARK: Karte

struct PollenGlance: View {
    let config: [String: JSON]
    @StateObject private var model: PollenModel
    @Environment(\.glanceSpace) private var space

    init(config: [String: JSON]) {
        self.config = config
        let p = SunBucket.place(config)
        _model = StateObject(wrappedValue: PollenModel.model(lat: p.lat, lon: p.lon))
    }

    var body: some View {
        let p = SunBucket.place(config)
        Group {
            if let today = model.days.first {
                content(today)
            } else if model.failed {
                Text("Pollendaten gerade nicht erreichbar").foregroundColor(Theme.secondary)
            } else {
                ProgressView()
            }
        }
        .task { await model.load(lat: p.lat, lon: p.lon) }
    }

    @ViewBuilder private func content(_ today: PollenDay) -> some View {
        let kinds = PollenBucket.shown(config)
        let active = kinds.filter { $0.level(today.levels[$0.id] ?? 0) > 0 }
            .sorted { $0.level(today.levels[$0.id] ?? 0) > $1.level(today.levels[$1.id] ?? 0) }
        let uv = PollenBucket.uvInfo(today.uvMax)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "sun.max.fill").foregroundColor(uv.color)
                Text("UV \(Int(today.uvMax.rounded()))").font(.title2.weight(.semibold).monospacedDigit())
                Text(uv.text).foregroundColor(Theme.secondary)
                Spacer(minLength: 0)
            }
            if active.isEmpty {
                Text("Heute kein Pollenflug").font(.headline)
                if space.height > 110 {
                    Text(PollenBucket.shown(config).map { $0.name }.joined(separator: ", ") + " – alles ruhig")
                        .font(.subheadline).foregroundColor(Theme.secondary).lineLimit(2)
                }
            } else {
                let rows = max(1, fitRows(space.height - 40, row: 28, max: 5))
                ForEach(Array(active.prefix(rows))) { k in
                    PollenLevelRow(kind: k, level: k.level(today.levels[k.id] ?? 0))
                }
            }
        }
    }
}

struct PollenLevelRow: View {
    let kind: PollenBucket.Kind
    let level: Int
    var body: some View {
        HStack(spacing: 10) {
            Text(kind.name).font(.body)
            Spacer(minLength: 4)
            PollenDots(level: level)
            Text(PollenBucket.levelNames[level]).font(.subheadline).foregroundColor(Theme.secondary)
                .frame(width: 56, alignment: .trailing)
        }
        .frame(height: 26)
    }
}

struct PollenDots: View {
    let level: Int
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { i in
                Capsule().fill(i <= level ? PollenBucket.levelColor(level) : Color.gray.opacity(0.2))
                    .frame(width: 14, height: 6)
            }
        }
    }
}

// MARK: App

struct PollenDetail: View {
    let config: [String: JSON]
    @StateObject private var model: PollenModel

    init(config: [String: JSON]) {
        self.config = config
        let p = SunBucket.place(config)
        _model = StateObject(wrappedValue: PollenModel.model(lat: p.lat, lon: p.lon))
    }

    var body: some View {
        let p = SunBucket.place(config)
        List {
            if let today = model.days.first {
                let uv = PollenBucket.uvInfo(today.uvMax)
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(today.uvMax.rounded()))").font(.system(size: 52, weight: .semibold).monospacedDigit())
                            VStack(alignment: .leading) {
                                Text(uv.text).font(.title3.weight(.semibold)).foregroundColor(uv.color)
                                Text("UV-Index heute, höchster Wert").font(.subheadline).foregroundColor(Theme.secondary)
                            }
                        }
                        Text(uv.tip).font(.subheadline)
                        UVCurve(hours: today.uvHours).frame(height: 90).padding(.top, 6)
                    }
                    .padding(.vertical, 6)
                } header: { Text("UV · " + p.city) }

                Section {
                    ForEach(PollenBucket.shown(config)) { k in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k.name)
                                Text("Saison " + k.months).font(.caption).foregroundColor(Theme.secondary)
                            }
                            Spacer()
                            ForEach(model.days.prefix(3)) { d in
                                let l = k.level(d.levels[k.id] ?? 0)
                                VStack(spacing: 4) {
                                    PollenDots(level: l)
                                    Text(PollenFmt.day(d.date)).font(.caption2).foregroundColor(Theme.secondary)
                                }
                                .frame(width: 58)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: { Text("Pollenflug") } footer: {
                    Text("Gering, mittel, stark – nach Körnern pro m³ Luft. Daten: Open-Meteo / Copernicus (CAMS).")
                }

                Section("Nächste Tage") {
                    ForEach(model.days.dropFirst()) { d in
                        let u = PollenBucket.uvInfo(d.uvMax)
                        HStack {
                            Text(PollenFmt.day(d.date, long: true))
                            Spacer()
                            Text("UV \(Int(d.uvMax.rounded()))").monospacedDigit()
                            Text(u.text).foregroundColor(u.color).frame(width: 80, alignment: .trailing)
                        }
                    }
                }
            } else if model.failed {
                Text("Pollendaten gerade nicht erreichbar – später noch mal.").foregroundColor(Theme.secondary)
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
        }
        .listStyle(.insetGrouped)
        .task { await model.load(lat: p.lat, lon: p.lon) }
    }
}

/// UV-Index über den Tag als Balken (6–20 Uhr), jetzt hervorgehoben
struct UVCurve: View {
    let hours: [UVHour]
    var body: some View {
        let list = hours.filter { $0.hour >= 6 && $0.hour <= 20 }
        let top = max(6, list.map { $0.uv }.max() ?? 0)
        let now = Calendar.current.component(.hour, from: Date())
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(list, id: \.hour) { h in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(PollenBucket.uvInfo(h.uv).color.opacity(h.hour == now ? 1 : 0.55))
                        .frame(height: max(2, CGFloat(h.uv / top) * 64))
                    Text(h.hour % 3 == 0 ? "\(h.hour)" : " ").font(.system(size: 9)).foregroundColor(Theme.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

enum PollenFmt {
    static func day(_ d: Date, long: Bool = false) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Heute" }
        if cal.isDateInTomorrow(d) { return "Morgen" }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = long ? "EEEE" : "EE"
        return f.string(from: d)
    }
}

// MARK: Einstellungen

struct PollenSettings: View {
    @Binding var config: [String: JSON]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CityPicker(config: $config)
            Text("WELCHE POLLEN").font(.footnote).foregroundColor(Theme.secondary)
            ForEach(PollenBucket.kinds) { k in
                Toggle(k.name, isOn: Binding(
                    get: { PollenBucket.shown(config).contains(k) },
                    set: { on in
                        var ids = PollenBucket.shown(config).map { $0.id }
                        if on { ids.append(k.id) } else { ids.removeAll { $0 == k.id } }
                        if ids.isEmpty { ids = [k.id] }
                        config["types"] = .array(ids.map { JSON.string($0) })
                    }))
            }
        }
    }
}
