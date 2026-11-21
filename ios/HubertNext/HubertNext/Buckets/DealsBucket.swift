import SwiftUI
import SafariServices
import Combine   // ObservableObject und @Published (das Projekt verlangt den Import ausdrücklich)

// ============================================================
// Deals-Bucket – gute Angebote zu dem, was man sucht.
// Aufbau wie der App Store:
//  • Bereiche antippen (Mode, Streetwear, Schuhe, Make-up, Pflege, Parfum,
//    Taschen & Schmuck, Shops … bis Technik) → passende Suchen sind vorgewählt
//  • Mode: der Server kennt die Trends der Saison, sortiert Angesagtes nach
//    vorn, lässt Basic-Marken weg und liefert „Gerade im Trend“
//  • Karte: Produkt-Kacheln mit Bild, Preis, Rabatt
//  • Alle Deals: je Suche eine Reihe zum Wischen, „Alle ›“ als Raster
// Passt auch ungefähr (Umlaute, Mehrzahl, Tippfehler, Synonyme) – macht der Server.
// Quelle: mydealz über die Supabase-Funktion „deals“.
// Einstellungen: watch = [{ id, t, alts, not, max, a (Bereich) }], min (Temperatur), hot (Bool)
// ============================================================

// MARK: Modelle

struct Deal: Decodable, Identifiable, Hashable {
    let id: String
    let t: String
    let m: String?
    let p: Double?
    let pt: String?
    let temp: Int?
    let cat: String?
    let img: String?
    let u: String
    let x: String?
    let d: String
    let off: Int?          // Rabatt in % (aus dem Titel)
    let code: Bool?        // Gutschein statt Produkt
    let hype: Int?         // Trend-Punkte 0–6 (angesagte Marken, Modelle, Schnitte)

    var date: Date { Fmt.date(d) ?? Date() }
    /// Gerade angesagt (zeigt die Trend-Plakette)
    var trendy: Bool { (hype ?? 0) >= 3 }
    /// Reihenfolge wie beim Server: neu zuerst, Angesagtes rutscht bis zu drei Tage nach vorn
    var rank: Date { date.addingTimeInterval(Double(max(0, hype ?? 0)) * 12 * 3600) }
    var image: URL? { img.flatMap { URL(string: $0) } }
    /// Bilder liefert mydealz in festen Größen – Kacheln in 300 × 300, Details größer
    var tileImage: URL? { sized("300x300") }
    var bigImage: URL? { sized("768x768") }
    var link: URL? { URL(string: u) }
    var priceText: String? {
        if let p = p { return p == 0 ? "Gratis" : DealFmt.euro(p) }
        return pt
    }
    private func sized(_ s: String) -> URL? {
        img.flatMap { URL(string: $0.replacingOccurrences(of: "/re/150x150/", with: "/re/\(s)/")) }
    }
}

struct DealGroup: Decodable { let t: String; let n: Int; let deals: [Deal] }
/// Ein Treffer mit den Suchen, die gepasst haben
struct DealHit: Identifiable {
    let deal: Deal
    var terms: [String]
    var id: String { deal.id }
}
struct DealMatch: Decodable {
    let at: String
    let groups: [DealGroup]
    let hot: [Deal]
    let trend: [Deal]?      // angesagte Mode der letzten Tage (ältere Server liefern nichts)
}
struct DealPreview: Decodable {
    struct Std: Decodable { let alts: [String]; let not: [String] }
    let n: Int
    let deals: [Deal]
    let std: Std
}
/// Ein Bereich mit Vorschlägen (vom Server)
struct DealCatalog: Codable, Identifiable, Hashable {
    struct Item: Codable, Hashable { let t: String; let alts: [String]; let not: [String]; let s: Bool? }
    let id: String
    let name: String
    let emoji: String
    let items: [Item]
    /// Was beim Antippen des Bereichs vorgewählt wird
    var starters: [Item] { let s = items.filter { $0.s == true }; return s.isEmpty ? Array(items.prefix(3)) : s }
}

/// Eine Suche (Stichwort)
struct DealWatch: Hashable, Identifiable {
    var id = UUID().uuidString.lowercased()
    var t: String
    var alts: [String] = []
    var not: [String] = []
    var max: Double? = nil
    var area: String? = nil

    init(t: String, alts: [String] = [], not: [String] = [], max: Double? = nil, area: String? = nil) {
        self.t = t; self.alts = alts; self.not = not; self.max = max; self.area = area
    }

    init?(_ j: JSON) {
        guard let o = j.object, let t = o["t"]?.string, !t.isEmpty else { return nil }
        self.t = t
        id = o["id"]?.string ?? t.lowercased()
        alts = (o["alts"]?.array ?? []).compactMap(\.string)
        not = (o["not"]?.array ?? []).compactMap(\.string)
        max = o["max"]?.double
        area = o["a"]?.string
    }

    var json: JSON {
        var o: [String: JSON] = ["id": .string(id), "t": .string(t), "alts": .array(alts.map { .string($0) }), "not": .array(not.map { .string($0) })]
        if let m = max { o["max"] = .number(m) }
        if let a = area { o["a"] = .string(a) }
        return .object(o)
    }

    /// Was an den Server geht
    var request: [String: Any] {
        var o: [String: Any] = ["t": t, "alts": alts, "not": not]
        if let m = max { o["max"] = m }
        return o
    }

    /// „bis 100 € · auch: Earbuds · nicht: Hülle“
    var summary: String {
        var parts: [String] = []
        if let m = max { parts.append("bis " + DealFmt.euro(m)) }
        if !alts.isEmpty { parts.append("auch: " + alts.joined(separator: ", ")) }
        if !not.isEmpty { parts.append("nicht: " + not.joined(separator: ", ")) }
        return parts.isEmpty ? "Alle passenden Deals" : parts.joined(separator: " · ")
    }
}

enum DealFmt {
    static func euro(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE"); f.numberStyle = .currency; f.currencyCode = "EUR"
        f.minimumFractionDigits = v.rounded() == v ? 0 : 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "\(v) €"
    }

    /// Zahl ohne Währung für Eingabefelder („49,9“, „100“)
    static func plain(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE"); f.numberStyle = .decimal; f.usesGroupingSeparator = false
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    static func tempColor(_ t: Int) -> Color { t >= 300 ? .red : t >= 100 ? .orange : Theme.secondary }
}

/// Symbol und Farbe je Bereich
enum DealArea {
    static func symbol(_ id: String?) -> String {
        ["mode": "tshirt", "streetwear": "bolt", "schuhe": "figure.walk", "makeup": "paintbrush.pointed", "pflege": "drop",
         "parfum": "sparkles", "accessoires": "bag", "shops": "tag", "wohnen": "house", "technik": "headphones",
         "gaming": "gamecontroller", "haushalt": "wrench.and.screwdriver", "einkauf": "cart", "freizeit": "gift",
         "reisen": "airplane", "aktionen": "percent", "trend": "flame"][id ?? ""] ?? "magnifyingglass"
    }
    static func color(_ id: String?) -> Color {
        ["mode": .pink, "streetwear": .indigo, "schuhe": .orange, "makeup": .red, "pflege": .teal, "parfum": .purple,
         "accessoires": .brown, "shops": .blue, "wohnen": .yellow, "technik": .blue, "gaming": .green, "haushalt": .gray,
         "einkauf": .mint, "freizeit": .cyan, "reisen": .blue, "aktionen": .orange, "trend": Theme.accent][id ?? ""] ?? Theme.accent
    }
}

/// Runder Kreis mit Bereichssymbol
struct DealAreaIcon: View {
    let area: String?
    var size: CGFloat = 28
    var filled = true
    var body: some View {
        let c = DealArea.color(area)
        Image(systemName: DealArea.symbol(area))
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundColor(filled ? .white : c)
            .frame(width: size, height: size)
            .background(Circle().fill(filled ? c : c.opacity(0.15)))
            .accessibilityHidden(true)
    }
}

// MARK: Bucket

enum DealsBucket {
    static let kind = BucketKind(
        id: "deals", name: "Deals", symbol: "tag", tint: .pink, art: .glance,
        interests: ["shopping", "freizeit", "technik", "haushalt"],
        blurb: "Angebote zu dem, was du suchst – Mode, Beauty, Technik und mehr.",
        defaultConfig: [:],
        needsSetup: { watch($0).isEmpty },
        glance: { inst, size in AnyView(DealsGlance(config: inst.config, size: size)) },
        detail: { inst in AnyView(DealsDetail(config: inst.config)) },
        itemLinks: true,
        settings: { binding in AnyView(DealsSettings(config: binding)) }
    )

    static func watch(_ c: [String: JSON]) -> [DealWatch] { (c["watch"]?.array ?? []).compactMap { DealWatch($0) } }
    static func store(_ w: [DealWatch], in c: inout [String: JSON]) { c["watch"] = .array(w.map(\.json)) }
    /// Mindest-Temperatur: 0 = alle (außer kalte), 100 = nur heiße
    static func minTemp(_ c: [String: JSON]) -> Int { Int(c["min"]?.double ?? 0) }
    static func showHot(_ c: [String: JSON]) -> Bool { c["hot"]?.bool ?? true }

    /// Bereich einer Suche – gespeichert oder aus den Vorschlägen erkannt (ältere Karten)
    static func area(of w: DealWatch) -> String? {
        if let a = w.area { return a }
        return DealService.shared.catalog.first { c in c.items.contains { $0.t.caseInsensitiveCompare(w.t) == .orderedSame } }?.id
    }

    /// Bereiche, in denen „Gerade im Trend“ mitläuft
    static let styleAreas: Set<String> = ["mode", "streetwear", "schuhe", "accessoires"]
    static func wantsTrend(_ w: [DealWatch]) -> Bool { w.contains { styleAreas.contains(area(of: $0) ?? "") } }

    /// Treffer aller Suchen, ohne Doppelte, neueste zuerst (Angesagtes etwas weiter vorn)
    static func merged(_ m: DealMatch) -> [DealHit] {
        var order: [String] = []
        var byId: [String: DealHit] = [:]
        for g in m.groups {
            for d in g.deals {
                if var e = byId[d.id] { e.terms.append(g.t); byId[d.id] = e }
                else { byId[d.id] = DealHit(deal: d, terms: [g.t]); order.append(d.id) }
            }
        }
        return order.compactMap { byId[$0] }.sorted { $0.deal.rank > $1.deal.rank }
    }

    static func hits(_ m: DealMatch, for term: String) -> [DealHit] {
        (m.groups.first { $0.t == term }?.deals ?? []).map { DealHit(deal: $0, terms: [term]) }
    }
}

// MARK: Laden

final class DealService: ObservableObject {
    static let shared = DealService()
    @Published private(set) var results: [String: DealMatch] = [:]
    private var loadedAt: [String: Date] = [:]
    private let api = SupabaseClient.shared

    static func key(_ w: [DealWatch], min: Int) -> String {
        w.map { [$0.t, $0.alts.joined(separator: ","), $0.not.joined(separator: ","), $0.max.map { "\($0)" } ?? ""].joined(separator: "|") }
            .joined(separator: ";") + "#\(min)"
    }

    /// Alle 10 Minuten neu (der Server liest mydealz ohnehin höchstens alle 5 Minuten)
    func load(_ w: [DealWatch], min: Int, force: Bool = false) async {
        guard !w.isEmpty else { return }
        let k = Self.key(w, min: min)
        if !force, let t = loadedAt[k], Date().timeIntervalSince(t) < 598 { return }
        do {
            let obj: [String: Any] = ["watch": w.map { $0.request }, "min": min]
            let body = try JSONSerialization.data(withJSONObject: obj)
            let data = try await api.raw("POST", "/functions/v1/deals/match", body: body)
            results[k] = try JSONDecoder().decode(DealMatch.self, from: data)
            loadedAt[k] = Date()
        } catch { print("Deals:", error) }
    }

    func preview(_ w: DealWatch, min: Int) async throws -> DealPreview {
        var q = [URLQueryItem(name: "t", value: w.t), URLQueryItem(name: "min", value: String(min))]
        if !w.alts.isEmpty { q.append(URLQueryItem(name: "alts", value: w.alts.joined(separator: ","))) }
        if !w.not.isEmpty { q.append(URLQueryItem(name: "not", value: w.not.joined(separator: ","))) }
        if let m = w.max { q.append(URLQueryItem(name: "max", value: String(m))) }
        let data = try await api.raw("GET", "/functions/v1/deals/preview", query: q)
        return try JSONDecoder().decode(DealPreview.self, from: data)
    }

    /// Bereiche und Vorschläge (vom Server, damit neue ohne App-Update dazukommen)
    @Published private(set) var catalog: [DealCatalog] = {
        guard let d = UserDefaults.standard.data(forKey: "deals.catalog.v3"),
              let c = try? JSONDecoder().decode([DealCatalog].self, from: d) else { return [] }
        return c
    }()
    private var catalogAt: Date?

    func loadCatalog() async {
        if let t = catalogAt, Date().timeIntervalSince(t) < 600 { return }
        guard let data = try? await api.raw("GET", "/functions/v1/deals/catalog"),
              let c = try? JSONDecoder().decode([DealCatalog].self, from: data) else { return }
        catalog = c
        catalogAt = Date()
        UserDefaults.standard.set(data, forKey: "deals.catalog.v3")
    }
}

// MARK: Black Week

enum BlackWeek {
    /// Black Friday = Tag nach Thanksgiving (4. Donnerstag im November)
    static func friday(_ year: Int) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let first = cal.date(from: DateComponents(year: year, month: 11, day: 1))!
        let wd = cal.component(.weekday, from: first)          // So = 1 … Do = 5
        let firstThu = 1 + (5 - wd + 7) % 7
        return cal.date(from: DateComponents(year: year, month: 11, day: firstThu + 22))!
    }

    /// Hinweis: zwei Wochen vorher bis Cyber Monday
    static var banner: String? {
        let bf = friday(Calendar.current.component(.year, from: Date()))
        let days = Fmt.dayDiff(bf)
        switch days {
        case 5...14: return "Black Friday in \(days) Tagen"
        case 2...4: return "Black Week · Black Friday in \(days) Tagen"
        case 1: return "Black Week · morgen ist Black Friday"
        case 0: return "Heute ist Black Friday"
        case -2 ... -1: return "Black Week · noch bis Cyber Monday"
        case -3: return "Heute ist Cyber Monday"
        default: return nil
        }
    }
}

// MARK: Bausteine

/// Produkt-Kachel: Bild (quadratisch, weißer Grund), Rabatt, Preis, Titel
struct DealTile: View {
    let deal: Deal
    var label: String? = nil
    var width: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.white
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    AsyncImage(url: deal.tileImage ?? deal.image) { img in img.resizable().scaledToFit() } placeholder: {
                        Image(systemName: "tag").font(.title2).foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                    .padding(8)
                )
                .overlay(badges, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 0.5))
            HStack(spacing: 6) {
                if let p = deal.priceText { Text(p).font(.subheadline.weight(.bold)).foregroundColor(.primary) }
                if let t = deal.temp, t >= 100 {
                    Text("\(t)°").font(.caption.weight(.semibold)).foregroundColor(DealFmt.tempColor(t))
                }
            }
            .lineLimit(1)
            Text(deal.t).font(.caption).foregroundColor(.primary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text([label, deal.m].compactMap { $0 }.joined(separator: " · "))
                .font(.caption2).foregroundColor(Theme.secondary).lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var badges: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let o = deal.off {
                Text("−\(o) %").font(.caption.weight(.bold)).foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent))
            }
            if deal.code == true {
                Text("Gutschein").font(.caption2.weight(.semibold)).foregroundColor(.primary)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.regularMaterial))
            }
            if deal.trendy {
                Label("Trend", systemImage: "flame.fill").font(.caption2.weight(.semibold)).foregroundColor(Theme.accent)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.regularMaterial))
            }
        }
        .padding(6)
    }
}

/// Listenzeile (für schmale Karten und Vorschauen): Bild, Titel, Preis · Händler
struct DealRow: View {
    let deal: Deal
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            DealThumb(url: deal.tileImage ?? deal.image, size: compact ? 44 : 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(deal.t).font(compact ? .subheadline : .body).lineLimit(2).foregroundColor(.primary)
                HStack(spacing: 6) {
                    if let p = deal.priceText { Text(p).fontWeight(.semibold).foregroundColor(.primary) }
                    if let o = deal.off { Text("−\(o) %").fontWeight(.semibold).foregroundColor(Theme.accent) }
                    if let m = deal.m { Text(m).foregroundColor(Theme.secondary).lineLimit(1) }
                    Spacer(minLength: 4)
                    Text(Fmt.ago(deal.date)).foregroundColor(Theme.secondary).lineLimit(1)
                }
                .font(.caption.monospacedDigit())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct DealThumb: View {
    let url: URL?
    let size: CGFloat
    var body: some View {
        Color.white
            .overlay(
                AsyncImage(url: url) { img in img.resizable().scaledToFit() } placeholder: {
                    Image(systemName: "tag").foregroundColor(Theme.secondary)
                }
                .padding(3)
            )
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Black-Week-Hinweis als ruhige Zeile
struct BlackWeekBanner: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "tag.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Theme.accent)
            .lineLimit(1)
    }
}

// MARK: Karte

struct DealsGlance: View {
    let config: [String: JSON]
    let size: BucketSize
    @ObservedObject private var service = DealService.shared
    @Environment(\.glanceSpace) private var space
    @Environment(\.editBucket) private var editBucket

    private var watch: [DealWatch] { DealsBucket.watch(config) }
    private var minTemp: Int { DealsBucket.minTemp(config) }
    private var key: String { DealService.key(watch, min: minTemp) }

    var body: some View {
        content.refreshing(id: key, every: { 600 }) { await DealService.shared.load(watch, min: minTemp) }
    }

    @ViewBuilder private var content: some View {
        if watch.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Was suchst du?").font(.headline)
                Text("Mode, Schuhe, Make-up, Technik … – such dir Bereiche aus.").font(.subheadline).foregroundColor(Theme.secondary)
                Button("Einrichten") { editBucket() }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
            }
        } else if let m = service.results[key] {
            let hits = DealsBucket.merged(m)
            let fallback = hits.isEmpty && DealsBucket.showHot(config)
            // Wer Mode sucht, bekommt statt „heiß bei allen“ das, was gerade angesagt ist
            let trend = DealsBucket.wantsTrend(watch) ? (m.trend ?? []) : []
            let list = fallback ? (trend.isEmpty ? m.hot : trend).map { DealHit(deal: $0, terms: []) } : hits
            let banner = BlackWeek.banner
            VStack(alignment: .leading, spacing: 8) {
                if let b = banner { BlackWeekBanner(text: b) }
                if list.isEmpty {
                    Text("Gerade nichts Neues – Hubert schaut alle 10 Minuten nach.").foregroundColor(Theme.secondary)
                } else {
                    if fallback {
                        Text(trend.isEmpty ? "Zu deinen Suchen gerade nichts – heiß bei allen:" : "Zu deinen Suchen gerade nichts – gerade im Trend:")
                            .font(.caption).foregroundColor(Theme.secondary)
                    }
                    let h = space.height - (banner == nil ? 0 : 28) - (fallback ? 22 : 0)
                    // Kacheln nur, wenn mindestens eine ganze Reihe hineinpasst – sonst Liste
                    if space.width >= 280 && h >= layout.tileH + Pages.dots { tiles(list, height: h) } else { rows(list, height: h) }
                }
            }
        } else {
            Text("Lädt …").foregroundColor(Theme.secondary)
        }
    }

    /// Kacheln: so viele Spalten, wie mit ca. 120 pt Breite hineinpassen
    private struct TileLayout { let cols: Int; let w: CGFloat; let tileH: CGFloat }
    private static let gap: CGFloat = 12
    private var layout: TileLayout {
        let gap = Self.gap
        let cols = max(2, Int((space.width + gap) / (120 + gap)))
        let w = floor((space.width - gap * CGFloat(cols - 1)) / CGFloat(cols))
        return TileLayout(cols: cols, w: w, tileH: w + 84)      // Bild + Preis + 2 Zeilen Titel + Händler
    }

    @ViewBuilder private func tiles(_ list: [DealHit], height: CGFloat) -> some View {
        let gap = Self.gap
        let cols = layout.cols
        let w = layout.w
        let tileH = layout.tileH
        let rowsPerPage = max(1, Int((height - Pages.dots + gap) / (tileH + gap)))
        let per = cols * rowsPerPage
        let pages = stride(from: 0, to: min(list.count, per * 6), by: per).map { Array(list[$0 ..< min($0 + per, list.count)]) }
        GlancePager(pages: pages) { page in
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(w), spacing: gap, alignment: .top), count: cols), alignment: .leading, spacing: gap) {
                ForEach(page) { e in
                    NavigationLink(destination: DealDetailView(deal: e.deal, terms: e.terms)) {
                        DealTile(deal: e.deal, label: e.terms.first, width: w)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Schmale Karte: Liste
    @ViewBuilder private func rows(_ list: [DealHit], height: CGFloat) -> some View {
        GlancePager(pages: Pages.split(list, height: height, row: 60)) { page in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(page.enumerated()), id: \.element.id) { i, e in
                    if i > 0 { Divider() }
                    NavigationLink(destination: DealDetailView(deal: e.deal, terms: e.terms)) {
                        DealRow(deal: e.deal, compact: true).padding(.vertical, 6).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: Alle Deals – je Suche eine Reihe

struct DealsDetail: View {
    let config: [String: JSON]
    @ObservedObject private var service = DealService.shared
    @Environment(\.editBucket) private var editBucket

    private var watch: [DealWatch] { DealsBucket.watch(config) }
    private var minTemp: Int { DealsBucket.minTemp(config) }
    private var key: String { DealService.key(watch, min: minTemp) }

    var body: some View {
        let m = service.results[key]
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let b = BlackWeek.banner { BlackWeekBanner(text: b).padding(.horizontal, 20) }
                if watch.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Was suchst du?").font(.title2.weight(.bold))
                        Text("Wähle Bereiche wie Mode, Make-up oder Technik – Hubert sucht dann passende Angebote.")
                            .foregroundColor(Theme.secondary)
                        Button("Einrichten") { editBucket() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                    }
                    .padding(.horizontal, 20)
                } else if let m = m {
                    let trend = DealsBucket.wantsTrend(watch) ? (m.trend ?? []) : []
                    if !trend.isEmpty {
                        shelf(title: "Gerade im Trend", area: "trend", count: trend.count,
                              hits: trend.map { DealHit(deal: $0, terms: []) }, showLabel: false)
                    }
                    let empty = watch.filter { w in (m.groups.first { $0.t == w.t }?.n ?? 0) == 0 }
                    ForEach(watch.filter { w in !empty.contains(w) }) { w in
                        shelf(title: w.t, area: DealsBucket.area(of: w), count: m.groups.first { $0.t == w.t }?.n ?? 0,
                              hits: DealsBucket.hits(m, for: w.t), showLabel: false)
                    }
                    if !empty.isEmpty {
                        Text("Gerade nichts zu: " + empty.map(\.t).joined(separator: ", "))
                            .font(.footnote).foregroundColor(Theme.secondary).padding(.horizontal, 20)
                    }
                    if !m.hot.isEmpty {
                        shelf(title: "Heiß gerade", area: "aktionen", count: m.hot.count,
                              hits: m.hot.map { DealHit(deal: $0, terms: []) }, showLabel: false)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
                Text("Quelle: mydealz. Preise und Verfügbarkeit ändern sich schnell – im Deal steht, wo und wie lange.")
                    .font(.footnote).foregroundColor(Theme.secondary).padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.background.ignoresSafeArea())
        .refreshing(id: key, every: { 600 }) { await DealService.shared.load(watch, min: minTemp) }
        .task { await DealService.shared.loadCatalog() }
    }

    /// Eine Reihe: Kopf mit „Alle ›“, darunter Kacheln zum Wischen
    private func shelf(title: String, area: String?, count: Int, hits: [DealHit], showLabel: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(destination: DealSearchView(title: title, area: area, hits: hits)) {
                HStack(spacing: 10) {
                    DealAreaIcon(area: area, size: 28)
                    Text(title).font(.title3.weight(.bold)).foregroundColor(.primary).lineLimit(1)
                    Text("\(count)").font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary)
                    Spacer()
                    Text("Alle").foregroundColor(Theme.accent)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundColor(Theme.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(hits.prefix(12)) { e in
                        NavigationLink(destination: DealDetailView(deal: e.deal, terms: e.terms)) {
                            DealTile(deal: e.deal, label: showLabel ? e.terms.first : nil, width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

/// Alle Deals einer Suche als Raster
struct DealSearchView: View {
    let title: String
    let area: String?
    let hits: [DealHit]
    @State private var sort = 0          // 0 Top (wie vom Server: bei Mode Angesagtes vorn), 1 neueste, 2 günstigste, 3 höchster Rabatt

    private var sorted: [DealHit] {
        switch sort {
        case 1: return hits.sorted { $0.deal.date > $1.deal.date }
        case 2: return hits.sorted { ($0.deal.p ?? .greatestFiniteMagnitude) < ($1.deal.p ?? .greatestFiniteMagnitude) }
        case 3: return hits.sorted { ($0.deal.off ?? -1) > ($1.deal.off ?? -1) }
        default: return hits
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Sortieren", selection: $sort) {
                    Text("Top").tag(0); Text("Neueste").tag(1); Text("Günstigste").tag(2); Text("Rabatt").tag(3)
                }
                .pickerStyle(.segmented)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14, alignment: .top)], alignment: .leading, spacing: 18) {
                    ForEach(sorted) { e in
                        NavigationLink(destination: DealDetailView(deal: e.deal, terms: e.terms)) { DealTile(deal: e.deal) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Ein Deal

struct DealDetailView: View {
    let deal: Deal
    var terms: [String] = []
    @State private var web: URL?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Color.white
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 360)
                        .overlay(
                            AsyncImage(url: deal.bigImage ?? deal.image) { img in img.resizable().scaledToFit() } placeholder: { ProgressView() }
                                .padding(12)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxWidth: .infinity)
                    Text(deal.t).font(.title3.weight(.semibold))
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        if let p = deal.priceText { Text(p).font(.title.weight(.bold)) }
                        if let o = deal.off {
                            Text("−\(o) %").font(.headline).foregroundColor(.white)
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .background(Capsule().fill(Theme.accent))
                        }
                        Spacer()
                        if let t = deal.temp {
                            Text("\(t)°").font(.headline.monospacedDigit()).foregroundColor(DealFmt.tempColor(t))
                                .accessibilityLabel("\(t) Grad")
                        }
                    }
                    if let m = deal.m { Text("bei " + m + (deal.code == true ? " · Gutschein" : "")).foregroundColor(Theme.secondary) }
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
            }
            Section {
                Button { web = deal.link } label: {
                    Text("Zum Angebot").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent)
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            Section {
                if let x = deal.x, !x.isEmpty { Text(x) }
                HStack { Text("Eingestellt"); Spacer(); Text(Fmt.ago(deal.date)).foregroundColor(Theme.secondary) }
                if !terms.isEmpty { HStack { Text("Passt zu"); Spacer(); Text(terms.joined(separator: ", ")).foregroundColor(Theme.secondary) } }
                if let c = deal.cat { HStack { Text("Kategorie"); Spacer(); Text(c).foregroundColor(Theme.secondary) } }
                if deal.trendy {
                    Label("Gerade angesagt – Marke, Modell oder Schnitt sind in dieser Saison gefragt", systemImage: "flame.fill")
                        .foregroundColor(Theme.accent)
                }
            } footer: {
                Text("„Zum Angebot“ öffnet den Deal bei mydealz – innerhalb von Hubert.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(deal.m ?? "Deal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(get: { web.map { WebLink(url: $0) } }, set: { web = $0?.url })) { l in
            SafariView(url: l.url).ignoresSafeArea()
        }
    }
}

struct WebLink: Identifiable { let url: URL; var id: String { url.absoluteString } }

/// Webseite in Hubert (Safari-Ansicht, bleibt im geführten Zugriff in der App)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController(url: url)
        c.preferredControlTintColor = UIColor(Theme.accent)
        c.dismissButtonStyle = .close
        return c
    }
    func updateUIViewController(_ c: SFSafariViewController, context: Context) {}
}
