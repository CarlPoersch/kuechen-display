import SwiftUI
import SafariServices

// ============================================================
// Deals-Bucket – gute Angebote zu deinen Stichwörtern.
// Wie beim Einkaufszettel: Vorschläge sind schon da (mit Synonymen),
// eigene Stichwörter kommen dazu. Passt auch ungefähr: Groß/klein,
// Umlaute, Mehrzahl, Wortteile und Tippfehler (macht der Server).
// Quelle: mydealz über die Supabase-Funktion „deals“.
// Einstellungen: watch = [{ id, t, alts, not, max }], min (Temperatur), hot (Bool)
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

    var date: Date { Fmt.date(d) ?? Date() }
    var image: URL? { img.flatMap { URL(string: $0) } }
    /// Größeres Bild für die Detailansicht (mydealz liefert Vorschaubilder in 150 × 150)
    var bigImage: URL? { img.flatMap { URL(string: $0.replacingOccurrences(of: "/re/150x150/", with: "/re/768x768/")) } }
    var link: URL? { URL(string: u) }
    var priceText: String? {
        if let p = p { return p == 0 ? "Gratis" : DealFmt.euro(p) }
        return pt
    }
}

struct DealGroup: Decodable { let t: String; let n: Int; let deals: [Deal] }
/// Ein Treffer mit den Stichwörtern, die gepasst haben
struct DealHit: Identifiable {
    let deal: Deal
    var terms: [String]
    var id: String { deal.id }
}
struct DealMatch: Decodable { let at: String; let groups: [DealGroup]; let hot: [Deal] }
struct DealPreview: Decodable {
    struct Std: Decodable { let alts: [String]; let not: [String] }
    let n: Int
    let deals: [Deal]
    let std: Std
}
struct DealCatalog: Codable, Identifiable, Hashable {
    struct Item: Codable, Hashable { let t: String; let alts: [String]; let not: [String] }
    let name: String
    let emoji: String
    let items: [Item]
    var id: String { name }
}

/// Ein Stichwort, nach dem Hubert sucht
struct DealWatch: Hashable, Identifiable {
    var id = UUID().uuidString.lowercased()
    var t: String
    var alts: [String] = []
    var not: [String] = []
    var max: Double? = nil

    init(t: String, alts: [String] = [], not: [String] = [], max: Double? = nil) {
        self.t = t; self.alts = alts; self.not = not; self.max = max
    }

    init?(_ j: JSON) {
        guard let o = j.object, let t = o["t"]?.string, !t.isEmpty else { return nil }
        self.t = t
        id = o["id"]?.string ?? t.lowercased()
        alts = (o["alts"]?.array ?? []).compactMap(\.string)
        not = (o["not"]?.array ?? []).compactMap(\.string)
        max = o["max"]?.double
    }

    var json: JSON {
        var o: [String: JSON] = ["id": .string(id), "t": .string(t), "alts": .array(alts.map { .string($0) }), "not": .array(not.map { .string($0) })]
        if let m = max { o["max"] = .number(m) }
        return .object(o)
    }

    /// Was an den Server geht (ohne ID)
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

// MARK: Bucket

enum DealsBucket {
    static let defaults = ["Kopfhörer", "Kaffee", "Lego", "Staubsauger", "Gratis-Spiele"].map { DealWatch(t: $0) }

    static let kind = BucketKind(
        id: "deals", name: "Deals", symbol: "tag", tint: .red, art: .glance,
        interests: ["haushalt", "technik", "freizeit"], blurb: "Gute Angebote zu deinen Stichwörtern – von Kopfhörern bis Kaffee.",
        defaultConfig: ["watch": .array(defaults.map(\.json))],
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

    /// Treffer aller Stichwörter, ohne Doppelte, neueste zuerst – mit den Stichwörtern, die gepasst haben
    static func merged(_ m: DealMatch) -> [DealHit] {
        var order: [String] = []
        var byId: [String: DealHit] = [:]
        for g in m.groups {
            for d in g.deals {
                if var e = byId[d.id] { e.terms.append(g.t); byId[d.id] = e }
                else { byId[d.id] = DealHit(deal: d, terms: [g.t]); order.append(d.id) }
            }
        }
        return order.compactMap { byId[$0] }.sorted { $0.deal.date > $1.deal.date }
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

    /// Vorschläge (vom Server, damit neue ohne App-Update dazukommen)
    @Published private(set) var catalog: [DealCatalog] = {
        guard let d = UserDefaults.standard.data(forKey: "deals.catalog"),
              let c = try? JSONDecoder().decode([DealCatalog].self, from: d) else { return [] }
        return c
    }()

    func loadCatalog() async {
        guard let data = try? await api.raw("GET", "/functions/v1/deals/catalog"),
              let c = try? JSONDecoder().decode([DealCatalog].self, from: data) else { return }
        catalog = c
        UserDefaults.standard.set(data, forKey: "deals.catalog")
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

    /// Hinweis für die Karte: zwei Wochen vorher bis Cyber Monday
    static var banner: String? {
        let cal = Calendar.current
        let now = Date()
        let bf = friday(cal.component(.year, from: now))
        let days = Fmt.dayDiff(bf)
        switch days {
        case 5...14: return "Black Friday in \(days) Tagen"
        case 2...4: return "Black Week läuft · Black Friday in \(days) Tagen"
        case 1: return "Black Week läuft · morgen ist Black Friday"
        case 0: return "Heute ist Black Friday"
        case -2 ... -1: return "Black Week · noch bis Cyber Monday"
        case -3: return "Heute ist Cyber Monday"
        default: return nil
        }
    }
}

// MARK: Karte

struct DealsGlance: View {
    let config: [String: JSON]
    let size: BucketSize
    @ObservedObject private var service = DealService.shared
    @Environment(\.glanceSpace) private var space

    private var watch: [DealWatch] { DealsBucket.watch(config) }
    private var minTemp: Int { DealsBucket.minTemp(config) }
    private var key: String { DealService.key(watch, min: minTemp) }

    var body: some View {
        content.refreshing(id: key, every: { 600 }) { await DealService.shared.load(watch, min: minTemp) }
    }

    @ViewBuilder private var content: some View {
        if watch.isEmpty {
            Text("Füge Stichwörter hinzu – über den Regler oben rechts").foregroundColor(Theme.secondary)
        } else if let m = service.results[key] {
            let hits = DealsBucket.merged(m)
            let showHot = hits.isEmpty && DealsBucket.showHot(config)
            let list = showHot ? m.hot.map { DealHit(deal: $0, terms: []) } : hits
            VStack(alignment: .leading, spacing: 4) {
                if let b = BlackWeek.banner {
                    Label(b, systemImage: "tag.fill").font(.caption.weight(.semibold)).foregroundColor(Theme.accent).lineLimit(1)
                }
                if list.isEmpty {
                    Text("Gerade nichts Passendes – Hubert schaut alle 10 Minuten nach.").foregroundColor(Theme.secondary)
                } else {
                    if showHot { Text("Nichts zu deinen Stichwörtern – heiß gerade:").font(.caption).foregroundColor(Theme.secondary) }
                    GlancePager(pages: Pages.split(list, height: space.height - (BlackWeek.banner == nil ? 0 : 22) - (showHot ? 18 : 0), row: 60)) { page in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(page.enumerated()), id: \.element.id) { i, e in
                                if i > 0 { Divider() }
                                NavigationLink(destination: DealDetailView(deal: e.deal, terms: e.terms)) {
                                    HStack(spacing: 6) {
                                        DealRow(deal: e.deal, compact: true)
                                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                                            .foregroundColor(Color(UIColor.tertiaryLabel))
                                    }
                                    .padding(.vertical, 6).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        } else {
            Text("Lädt …").foregroundColor(Theme.secondary)
        }
    }
}

/// Eine Zeile: Bild, Titel, Preis · Händler · Temperatur
struct DealRow: View {
    let deal: Deal
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            DealThumb(url: deal.image, size: compact ? 44 : 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(deal.t).font(compact ? .subheadline : .body).lineLimit(2).foregroundColor(.primary)
                HStack(spacing: 6) {
                    if let p = deal.priceText { Text(p).fontWeight(.semibold).foregroundColor(Theme.accent) }
                    if let m = deal.m { Text(m).foregroundColor(Theme.secondary).lineLimit(1) }
                    if let t = deal.temp { Text("\(t)°").fontWeight(.semibold).foregroundColor(DealFmt.tempColor(t)) }
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
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(UIColor.tertiarySystemFill))
            if let u = url {
                AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: {
                    Image(systemName: "tag").foregroundColor(Theme.secondary)
                }
            } else {
                Image(systemName: "tag").foregroundColor(Theme.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: Alle Deals

struct DealsDetail: View {
    let config: [String: JSON]
    @ObservedObject private var service = DealService.shared
    @Environment(\.editBucket) private var editBucket
    @State private var only = ""          // "" = alle Stichwörter
    @State private var sort = 0           // 0 neueste, 1 günstigste, 2 heißeste

    private var watch: [DealWatch] { DealsBucket.watch(config) }
    private var minTemp: Int { DealsBucket.minTemp(config) }
    private var key: String { DealService.key(watch, min: minTemp) }

    private func sorted(_ l: [DealHit]) -> [DealHit] {
        switch sort {
        case 1: return l.sorted { ($0.deal.p ?? .greatestFiniteMagnitude) < ($1.deal.p ?? .greatestFiniteMagnitude) }
        case 2: return l.sorted { ($0.deal.temp ?? -1) > ($1.deal.temp ?? -1) }
        default: return l
        }
    }

    var body: some View {
        let m = service.results[key]
        let all = m.map(DealsBucket.merged) ?? []
        let list = sorted(all.filter { only.isEmpty || $0.terms.contains(only) })
        List {
            if let b = BlackWeek.banner {
                Section {
                    Label(b, systemImage: "tag.fill").font(.headline).foregroundColor(Theme.accent)
                }
            }
            if !watch.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("", "Alle", all.count)
                        ForEach(watch) { w in chip(w.t, w.t, m?.groups.first { $0.t == w.t }?.n ?? 0) }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                Picker("Sortieren", selection: $sort) {
                    Text("Neueste").tag(0); Text("Günstigste").tag(1); Text("Heißeste").tag(2)
                }
                .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if watch.isEmpty {
                Section {
                    Text("Noch keine Stichwörter.").foregroundColor(Theme.secondary)
                    Button("Stichwörter wählen") { editBucket() }
                }
            } else if m == nil {
                ProgressView()
            } else if list.isEmpty {
                Text(only.isEmpty ? "Gerade nichts Passendes." : "Zu „\(only)“ gerade nichts.").foregroundColor(Theme.secondary)
            } else {
                Section(header: Text(only.isEmpty ? "Passend zu deinen Stichwörtern" : only)) {
                    ForEach(list) { e in
                        NavigationLink(destination: DealDetailView(deal: e.deal, terms: e.terms)) { DealRow(deal: e.deal).padding(.vertical, 3) }
                    }
                }
            }
            if only.isEmpty, let hot = m?.hot, !hot.isEmpty {
                Section(header: Text("Heiß gerade")) {
                    ForEach(hot) { d in
                        NavigationLink(destination: DealDetailView(deal: d, terms: [])) { DealRow(deal: d).padding(.vertical, 3) }
                    }
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("Quelle: mydealz – Preise und Verfügbarkeit können sich schnell ändern. Die Temperatur (°) zeigt, wie gut die Community einen Deal findet.")
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await DealService.shared.load(watch, min: minTemp, force: true) }
        .refreshing(id: key, every: { 600 }) { await DealService.shared.load(watch, min: minTemp) }
    }

    private func chip(_ id: String, _ title: String, _ n: Int) -> some View {
        Button { withAnimation { only = id } } label: {
            HStack(spacing: 4) {
                Text(title)
                Text("\(n)").foregroundColor(only == id ? Color.white.opacity(0.8) : Theme.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 7)
            .foregroundColor(only == id ? .white : .primary)
            .background(Capsule().fill(only == id ? Theme.accent : Theme.card))
        }
        .buttonStyle(.plain)
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
                    if let u = deal.bigImage ?? deal.image {
                        AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fit) } placeholder: {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Text(deal.t).font(.title3.weight(.semibold))
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        if let p = deal.priceText { Text(p).font(.title.weight(.bold)).foregroundColor(Theme.accent) }
                        if let m = deal.m { Text(m).font(.headline).foregroundColor(Theme.secondary) }
                        Spacer()
                        if let t = deal.temp {
                            Text("\(t)°").font(.headline.monospacedDigit()).foregroundColor(DealFmt.tempColor(t))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(DealFmt.tempColor(t).opacity(0.12)))
                                .accessibilityLabel("\(t) Grad")
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            Section {
                if let x = deal.x, !x.isEmpty { Text(x).foregroundColor(.primary) }
                HStack {
                    Text("Eingestellt")
                    Spacer()
                    Text(Fmt.ago(deal.date)).foregroundColor(Theme.secondary)
                }
                if let c = deal.cat {
                    HStack { Text("Kategorie"); Spacer(); Text(c).foregroundColor(Theme.secondary) }
                }
                if !terms.isEmpty {
                    HStack { Text("Passt zu"); Spacer(); Text(terms.joined(separator: ", ")).foregroundColor(Theme.secondary) }
                }
            }
            Section {
                Button { web = deal.link } label: {
                    Label("Zum Deal", systemImage: "arrow.up.forward.square").font(.headline).frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Öffnet den Deal bei mydealz – innerhalb von Hubert.")
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
