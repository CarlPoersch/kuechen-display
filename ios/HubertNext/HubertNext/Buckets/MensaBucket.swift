import SwiftUI
import Combine
import CoreLocation

// ============================================================
// Mensa: Speiseplan jeder deutschen Mensa über OpenMensa (frei, ohne Schlüssel).
//  - Beim Hinzufügen Mensa wählen (Suche oder „in der Nähe“); nur Mensen mit Plan
//  - Ich bin: Studierende / Bedienstete / Gäste → passender Preis
//  - Ernährung: alles / vegetarisch / vegan → nur passende Gerichte
//    (beim Ändern: „Auch in der Küche vorbelegen?“)
//  - Karte: bis 14:15 heute, danach der nächste Tag; nur Hauptgerichte,
//    bei viel Platz auch Suppe, Beilagen, Desserts
//  - Favoriten: Gericht mit Stern merken – kommt es wieder, steht es oben
// Einstellungen: canteen, canteenName, canteenCity, role, diet, favs
// ============================================================

enum MensaBucket {
    static let kind = BucketKind(
        id: "mensa", name: "Mensa", symbol: "takeoutbag.and.cup.and.straw.fill", tint: .orange, art: .glance,
        interests: ["lernen"], blurb: "Speiseplan deiner Mensa – mit deinem Preis, vegan/vegetarisch und Lieblingsgerichten.",
        defaultConfig: ["role": .string("students"), "diet": .string("alle")],
        needsSetup: { $0["canteen"]?.double == nil },
        glance: { inst, _ in AnyView(MensaGlance(instance: inst)) },
        detail: { inst in AnyView(MensaDetail(bucketId: inst.id)) },
        settings: { binding in AnyView(MensaSettings(config: binding)) }
    )

    static func canteen(_ c: [String: JSON]) -> Int? { c["canteen"]?.double.map { Int($0) } }
    static func role(_ c: [String: JSON]) -> String { c["role"]?.string ?? "students" }
    static func diet(_ c: [String: JSON]) -> String { c["diet"]?.string ?? "alle" }
    static func favs(_ c: [String: JSON]) -> [String] { (c["favs"]?.array ?? []).compactMap(\.string) }

    /// Gerichtname zum Vergleichen: klein, ohne Akzente, Anführungszeichen und Satzzeichen
    /// Favoriten nach oben, sonst Reihenfolge des Plans behalten
    static func favFirst(_ list: [MensaMeal], _ isFav: (MensaMeal) -> Bool) -> [MensaMeal] {
        list.filter(isFav) + list.filter { !isFav($0) }
    }

    static func norm(_ s: String) -> String {
        let f = s.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        let kept = f.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }
}

// MARK: Daten

struct MensaCanteen: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let city: String?
    let address: String?
}

struct MensaDay: Decodable { let date: String; let closed: Bool }

struct MensaMeal: Decodable, Identifiable {
    struct Prices: Decodable { let students: Double?; let employees: Double?; let pupils: Double?; let others: Double? }
    let id: Int
    let name: String
    let category: String?
    let prices: Prices?
    let notes: [String]?

    private var lowNotes: [String] { (notes ?? []).map { $0.lowercased() } }
    var vegan: Bool { lowNotes.contains { $0.contains("vegan") } }
    var vegetarian: Bool { vegan || lowNotes.contains { $0.contains("vegetari") } }

    /// Fleisch/Fisch aus den Kennzeichnungen, z. B. [("🐷", "Schwein"), ("🐮", "Rind")];
    /// nicht vegetarisch ohne genaue Angabe → 🍖 Fleisch
    var animals: [(emoji: String, label: String)] {
        guard !vegetarian else { return [] }
        let kinds: [(String, String, [String])] = [
            ("🐔", "Geflügel", ["geflügel", "huhn", "hähnchen", "pute"]),
            ("🐷", "Schwein", ["schwein"]),
            ("🐮", "Rind", ["rind", "kalb"]),
            ("🐑", "Lamm", ["lamm", "schaf"]),
            ("🦌", "Wild", ["wild"]),
            ("🐟", "Fisch", ["fisch", "weichtier", "krebstier", "meeresfrücht"]),
        ]
        let out = kinds.filter { k in lowNotes.contains { n in k.2.contains { n.contains($0) } } }.map { (emoji: $0.0, label: $0.1) }
        return out.isEmpty ? [(emoji: "🍖", label: "Fleisch")] : out
    }

    /// Zusatzstoffe und Allergene (ohne die Ernährungs-Kennzeichen)
    var info: [String] {
        (notes ?? []).filter { n in
            let l = n.lowercased()
            return !l.contains("vegan") && !l.contains("vegetari") && n.count > 2
        }
    }

    func price(_ role: String) -> Double? {
        guard let p = prices else { return nil }
        switch role {
        case "employees": return p.employees ?? p.others
        case "others": return p.others ?? p.employees
        default: return p.students ?? p.pupils
        }
    }

    enum Group: Int, CaseIterable { case main, soup, side, dessert, other
        var title: String { ["Hauptgerichte", "Suppen", "Beilagen & Salate", "Desserts", "Weiteres"][rawValue] }
    }
    var group: Group {
        let c = (category ?? "").lowercased()
        if c.contains("suppe") || c.contains("eintopf") { return .soup }
        if c.contains("beilage") || c.contains("salat") || c.contains("gemüse") { return .side }
        if c.contains("dessert") || c.contains("nachspeise") || c.contains("nachtisch") || c.contains("kuchen") { return .dessert }
        if c.contains("getränk") || c.contains("frühstück") || c.contains("snack") || c.contains("brot") { return .other }
        return .main
    }

    func fits(_ diet: String) -> Bool {
        switch diet { case "vegan": return vegan; case "vegetarisch": return vegetarian; default: return true }
    }
}

enum MensaFmt {
    static func price(_ p: Double?) -> String {
        guard let p = p else { return "" }
        let f = NumberFormatter(); f.locale = Locale(identifier: "de_DE"); f.numberStyle = .currency; f.currencyCode = "EUR"
        return f.string(from: NSNumber(value: p)) ?? ""
    }
    static let ymd: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    /// „Heute“, „Morgen“, „Montag“ (diese Woche) oder „Mo, 1. Dez.“
    static func dayLabel(_ s: String, long: Bool = true) -> String {
        guard let d = ymd.date(from: s) else { return s }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Heute" }
        if cal.isDateInTomorrow(d) { return "Morgen" }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE")
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: d).day ?? 0
        f.dateFormat = days < 7 && long ? "EEEE" : "EEE, d. MMM"
        return f.string(from: d)
    }
    static func chip(_ s: String) -> (String, String) {
        guard let d = ymd.date(from: s) else { return (s, "") }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EE"
        let g = DateFormatter(); g.locale = Locale(identifier: "de_DE"); g.dateFormat = "d."
        return (Calendar.current.isDateInToday(d) ? "Heute" : f.string(from: d).replacingOccurrences(of: ".", with: ""), g.string(from: d))
    }
}

/// Lädt Pläne von OpenMensa und hält sie 30 Minuten vor
final class MensaService: ObservableObject {
    static let shared = MensaService()
    static let base = "https://openmensa.org/api/v2/"

    @Published private(set) var days: [Int: [MensaDay]] = [:]
    @Published private(set) var meals: [String: [MensaMeal]] = [:]     // "id|datum"
    @Published private(set) var failed: Set<Int> = []
    private var loadedAt: [Int: Date] = [:]
    private var all: [MensaCanteen] = []

    static func get<T: Decodable>(_ path: String, _ type: T.Type) async throws -> T {
        guard let url = URL(string: base + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url); req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static var today: String { MensaFmt.ymd.string(from: Date()) }

    /// Offene Tage ab heute
    func openDays(_ id: Int) -> [String] {
        (days[id] ?? []).filter { !$0.closed && $0.date >= Self.today }.map(\.date).sorted()
    }
    func meals(_ id: Int, _ date: String) -> [MensaMeal]? { meals["\(id)|\(date)"] }

    func load(_ id: Int, force: Bool = false) async {
        if !force, let t = loadedAt[id], Date().timeIntervalSince(t) < 1800 { return }
        do {
            let d = try await Self.get("canteens/\(id)/days", [MensaDay].self)
            days[id] = d
            let open = d.filter { !$0.closed && $0.date >= Self.today }.map(\.date).sorted().prefix(6)
            for date in open {
                if let m = try? await Self.get("canteens/\(id)/days/\(date)/meals", [MensaMeal].self) { meals["\(id)|\(date)"] = m }
            }
            loadedAt[id] = Date(); failed.remove(id)
        } catch {
            if days[id] == nil { failed.insert(id) }
            print("Mensa:", error)
        }
    }

    /// Hat die Mensa gerade einen Plan? (Mensen ohne Daten werden nicht angeboten)
    static func hasPlan(_ id: Int) async -> Bool {
        guard let d = try? await get("canteens/\(id)/days", [MensaDay].self) else { return false }
        let today = Self.today
        return d.contains { !$0.closed && $0.date >= today }
    }

    private func withPlan(_ list: [MensaCanteen]) async -> [MensaCanteen] {
        var ok: Set<Int> = []
        await withTaskGroup(of: (Int, Bool).self) { group in
            for c in list { group.addTask { (c.id, await MensaService.hasPlan(c.id)) } }
            for await (id, has) in group where has { ok.insert(id) }
        }
        return list.filter { ok.contains($0.id) }
    }

    /// Alle Mensen (OpenMensa, seitenweise), eine Woche auf dem Gerät gemerkt
    private func allCanteens() async -> [MensaCanteen] {
        if !all.isEmpty { return all }
        let key = "mensa.all.v1", keyAt = "mensa.all.at"
        if let d = UserDefaults.standard.data(forKey: key),
           Date().timeIntervalSince1970 - UserDefaults.standard.double(forKey: keyAt) < 7 * 86_400,
           let l = try? JSONDecoder().decode([MensaCanteen].self, from: d), !l.isEmpty {
            all = l; return l
        }
        var out: [MensaCanteen] = []
        for page in 1...10 {
            guard let l = try? await Self.get("canteens?page=\(page)", [MensaCanteen].self), !l.isEmpty else { break }
            out += l
        }
        if !out.isEmpty {
            all = out
            if let d = try? JSONEncoder().encode(out) {
                UserDefaults.standard.set(d, forKey: key)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: keyAt)
            }
        }
        return out
    }

    /// Suche nach Name oder Stadt („oth regensburg“, „mensa münchen“)
    func search(_ text: String) async -> [MensaCanteen] {
        let words = MensaBucket.norm(text).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        let hits = await allCanteens().filter { c in
            let hay = MensaBucket.norm(c.name + " " + (c.city ?? ""))
            return words.allSatisfy { hay.contains($0) }
        }
        // Mensen zuerst, Schulen & Kitas nach hinten
        let sorted = hits.sorted { a, b in
            let ma = MensaBucket.norm(a.name).contains("mensa"), mb = MensaBucket.norm(b.name).contains("mensa")
            return ma != mb ? ma : a.name < b.name
        }
        return await withPlan(Array(sorted.prefix(20)))
    }

    func nearby(_ loc: CLLocation) async -> [MensaCanteen] {
        let q = String(format: "canteens?near[lat]=%.5f&near[lng]=%.5f&near[dist]=15", loc.coordinate.latitude, loc.coordinate.longitude)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let l = try? await Self.get(q, [MensaCanteen].self) else { return [] }
        return await withPlan(Array(l.prefix(20)))
    }
}

/// Welcher Tag gezeigt wird: heute bis 14:15, danach der nächste Tag mit Plan
struct MensaTarget {
    let date: String?
    let closedToday: Bool      // heute Werktag, aber kein Plan

    static func make(_ open: [String], now: Date = Date()) -> MensaTarget {
        let today = MensaFmt.ymd.string(from: now)
        let cal = Calendar.current
        let h = cal.component(.hour, from: now), m = cal.component(.minute, from: now)
        let early = h < 14 || (h == 14 && m < 15)
        let date = open.first { $0 > today || ($0 == today && early) }
        let wd = cal.component(.weekday, from: now)   // 1 = So, 7 = Sa
        let weekday = wd >= 2 && wd <= 6
        return MensaTarget(date: date, closedToday: weekday && early && !open.contains(today))
    }
}

// MARK: Karte

struct MensaGlance: View {
    let instance: BucketInstance
    @ObservedObject private var service = MensaService.shared
    @Environment(\.glanceSpace) private var space
    @Environment(\.editBucket) private var editBucket

    private let row: CGFloat = 30

    var body: some View {
        let c = instance.config
        Group {
            if let id = MensaBucket.canteen(c) {
                content(id, c)
                    .task(id: id) {
                        while !Task.isCancelled {
                            await service.load(id)
                            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                        }
                    }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Wähle deine Mensa – Hubert zeigt dir dann jeden Tag, was es gibt.").foregroundColor(Theme.secondary)
                    Button("Mensa wählen") { editBucket() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                }
            }
        }
    }

    @ViewBuilder private func content(_ id: Int, _ c: [String: JSON]) -> some View {
        let target = MensaTarget.make(service.openDays(id))
        if let date = target.date, let all = service.meals(id, date) {
            let diet = MensaBucket.diet(c), favs = Set(MensaBucket.favs(c)), role = MensaBucket.role(c)
            let fit = all.filter { $0.fits(diet) }
            let isFav: (MensaMeal) -> Bool = { favs.contains(MensaBucket.norm($0.name)) }
            let mains = MensaBucket.favFirst(fit.filter { $0.group == .main }, isFav)
            // Platz übrig: erst Suppe, dann Beilagen, dann Desserts
            let extra = [MensaMeal.Group.soup, .side, .dessert].flatMap { g in MensaBucket.favFirst(fit.filter { $0.group == g }, isFav) }
            let h = space.height - 26
            let cap = fitRows(h, row: row, max: 99)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(MensaFmt.dayLabel(date)).font(.subheadline.weight(.semibold))
                    if target.closedToday { Text("· heute geschlossen").font(.subheadline).foregroundColor(Theme.secondary) }
                    Spacer(minLength: 0)
                    Text(c["canteenName"]?.string ?? "").font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                }
                if mains.isEmpty && extra.isEmpty {
                    Text(diet == "alle" ? "Noch keine Gerichte eingetragen" : "Heute nichts \(diet == "vegan" ? "Veganes" : "Vegetarisches") dabei")
                        .foregroundColor(Theme.secondary)
                } else if mains.count >= cap {
                    // Mehr Hauptgerichte als Platz: blättern
                    GlancePager(pages: Pages.split(mains, height: h, row: row)) { page in
                        VStack(alignment: .leading, spacing: 0) { ForEach(page) { MensaRow(meal: $0, role: role, fav: isFav($0)) } }
                    }
                } else {
                    // Hauptgerichte; ist noch Platz, Suppe, Beilagen und Desserts dazu
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(mains) { MensaRow(meal: $0, role: role, fav: isFav($0)) }
                        ForEach(Array(extra.prefix(max(0, cap - mains.count)))) { MensaRow(meal: $0, role: role, fav: isFav($0), quiet: true) }
                    }
                }
                Spacer(minLength: 0)
            }
        } else if service.days[id] != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gerade kein Speiseplan").font(.headline)
                Text("Vielleicht sind Ferien – sobald es einen Plan gibt, steht er hier. 🌴").font(.subheadline).foregroundColor(Theme.secondary)
            }
        } else if service.failed.contains(id) {
            Text("Speiseplan gerade nicht erreichbar").foregroundColor(Theme.secondary)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Eine Zeile: Stern/Blatt · Gericht · Preis
struct MensaRow: View {
    let meal: MensaMeal
    let role: String
    var fav = false
    var quiet = false

    var body: some View {
        HStack(spacing: 8) {
            MensaBadge(meal: meal, fav: fav).frame(width: 18)
            Text(meal.name).font(.subheadline.weight(fav ? .semibold : .regular))
                .foregroundColor(quiet ? Theme.secondary : .primary).lineLimit(1)
            Spacer(minLength: 6)
            Text(MensaFmt.price(meal.price(role))).font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary)
        }
        .frame(height: 30)
    }
}

/// Stern für Favoriten, sonst Blatt für vegan/vegetarisch
struct MensaBadge: View {
    let meal: MensaMeal
    let fav: Bool
    var body: some View {
        if fav { Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption) }
        else if meal.vegan { Image(systemName: "leaf.fill").foregroundColor(.green).font(.caption) }
        else if meal.vegetarian { Image(systemName: "leaf").foregroundColor(.green).font(.caption) }
        else { Text(meal.animals.first?.emoji ?? "🍖").font(.caption) }
    }
}

// MARK: Detail

struct MensaDetail: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @ObservedObject private var service = MensaService.shared
    @State private var day: String?
    @State private var open: Set<Int> = []

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        let c = config
        let id = MensaBucket.canteen(c)
        let days = id.map { service.openDays($0) } ?? []
        let selected = day ?? MensaTarget.make(days).date ?? days.first
        List {
            if !days.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(days, id: \.self) { d in
                                let ch = MensaFmt.chip(d), on = d == selected
                                Button { day = d } label: {
                                    VStack(spacing: 1) {
                                        Text(ch.0).font(.caption.weight(.semibold))
                                        Text(ch.1).font(.headline.monospacedDigit())
                                    }
                                    .foregroundColor(on ? .white : .primary)
                                    .frame(width: 58, height: 52)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(on ? Theme.accent : Color(UIColor.tertiarySystemFill)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(MensaFmt.dayLabel(d, long: false))
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            if let id = id, let d = selected, let all = service.meals(id, d) {
                let diet = MensaBucket.diet(c), favs = Set(MensaBucket.favs(c)), role = MensaBucket.role(c)
                let fit = all.filter { $0.fits(diet) }
                ForEach(MensaMeal.Group.allCases, id: \.rawValue) { g in
                    let list = MensaBucket.favFirst(fit.filter { $0.group == g }) { favs.contains(MensaBucket.norm($0.name)) }
                    if !list.isEmpty {
                        Section(g.title) {
                            ForEach(list) { m in mealRow(m, role: role, fav: favs.contains(MensaBucket.norm(m.name))) }
                        }
                    }
                }
                if fit.isEmpty {
                    Section { Text(diet == "alle" ? "Noch keine Gerichte eingetragen" : "An diesem Tag nichts \(diet == "vegan" ? "Veganes" : "Vegetarisches") dabei").foregroundColor(Theme.secondary) }
                }
            } else if id != nil && days.isEmpty && service.days[id!] != nil {
                Section { Text("Gerade kein Speiseplan – vielleicht sind Ferien. 🌴").foregroundColor(Theme.secondary) }
            } else if id != nil {
                Section { HStack(spacing: 10) { ProgressView(); Text("Lädt Speiseplan …").foregroundColor(Theme.secondary) } }
            }

            let favs = MensaBucket.favs(c)
            Section {
                if favs.isEmpty {
                    Label("Tippe auf den Stern bei einem Gericht – kommt es wieder, steht es oben.", systemImage: "star")
                        .font(.subheadline).foregroundColor(Theme.secondary)
                } else {
                    ForEach(favs, id: \.self) { f in
                        Label { Text(f.capitalized) } icon: { Image(systemName: "star.fill").foregroundColor(.yellow) }
                    }
                    .onDelete { idx in
                        store.updateConfig(bucketId) { cfg in
                            var l = MensaBucket.favs(cfg); l.remove(atOffsets: idx); cfg["favs"] = .array(l.map { .string($0) })
                        }
                    }
                }
            } header: { Text("Favoriten") } footer: {
                Text(footer(c))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(c["canteenName"]?.string ?? "Mensa")
        .task(id: id) { if let id = id { await service.load(id, force: true) } }
        .refreshable { if let id = id { await service.load(id, force: true) } }
    }

    private func footer(_ c: [String: JSON]) -> String {
        let who = ["students": "Studierende", "employees": "Bedienstete", "others": "Gäste"][MensaBucket.role(c)] ?? "Studierende"
        var s = "Preise für " + who
        switch MensaBucket.diet(c) { case "vegan": s += " · nur vegane Gerichte"; case "vegetarisch": s += " · nur vegetarische Gerichte"; default: break }
        return s + ". Daten: OpenMensa."
    }

    private func mealRow(_ m: MensaMeal, role: String, fav: Bool) -> some View {
        let expanded = open.contains(m.id)
        return HStack(alignment: .top, spacing: 12) {
            Button { toggleFav(m) } label: {
                Image(systemName: fav ? "star.fill" : "star").font(.body.weight(.semibold))
                    .foregroundColor(fav ? .yellow : Theme.secondary.opacity(0.6))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(fav ? "Aus Favoriten entfernen" : "Als Favorit merken")
            VStack(alignment: .leading, spacing: 4) {
                Text(m.name).font(.body.weight(fav ? .semibold : .regular))
                HStack(spacing: 8) {
                    if m.vegan { Label("vegan", systemImage: "leaf.fill").foregroundColor(.green) }
                    else if m.vegetarian { Label("vegetarisch", systemImage: "leaf").foregroundColor(.green) }
                    else { Text(m.animals.map { $0.emoji + " " + $0.label }.joined(separator: " · ")).foregroundColor(Theme.secondary) }
                    if !m.info.isEmpty {
                        Text(expanded ? "weniger" : "Allergene & Zusätze").foregroundColor(Theme.accent)
                    }
                }
                .font(.caption.weight(.medium))
                if expanded && !m.info.isEmpty {
                    Text(m.info.joined(separator: " · ")).font(.caption).foregroundColor(Theme.secondary)
                }
            }
            Spacer(minLength: 6)
            Text(MensaFmt.price(m.price(role))).font(.body.monospacedDigit()).foregroundColor(Theme.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { if !m.info.isEmpty { withAnimation { if expanded { open.remove(m.id) } else { open.insert(m.id) } } } }
    }

    private func toggleFav(_ m: MensaMeal) {
        let n = MensaBucket.norm(m.name)
        store.updateConfig(bucketId) { cfg in
            var l = MensaBucket.favs(cfg)
            if let i = l.firstIndex(of: n) { l.remove(at: i) } else { l.append(n) }
            cfg["favs"] = .array(l.map { .string($0) })
        }
    }
}

// MARK: Einstellungen

/// Ernährung app-weit merken (Küche nutzt sie als vorbelegten Filter)
enum DietPreference {
    private static let key = "hubert.diet.kitchen"
    /// Wert für den Küchenfilter: "Alle", "Vegetarisch", "Vegan"
    static var kitchen: String {
        get { UserDefaults.standard.string(forKey: key) ?? "Alle" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func kitchenValue(_ mensaDiet: String) -> String {
        mensaDiet == "vegan" ? "Vegan" : mensaDiet == "vegetarisch" ? "Vegetarisch" : "Alle"
    }
}

struct MensaSettings: View {
    @Binding var config: [String: JSON]
    @State private var query = ""
    @State private var results: [MensaCanteen] = []
    @State private var searching = false
    @State private var locating = false
    @State private var note: String?
    @State private var askKitchen = false

    private var roleBinding: Binding<String> {
        Binding(get: { MensaBucket.role(config) }, set: { config["role"] = .string($0) })
    }
    private var dietBinding: Binding<String> {
        Binding(get: { MensaBucket.diet(config) }, set: { v in
            config["diet"] = .string(v)
            // Beim Aktivieren fragen, ob die Küche das auch übernehmen soll
            if DietPreference.kitchenValue(v) != DietPreference.kitchen { askKitchen = true }
        })
    }

    var body: some View {
        // Gewählte Mensa
        if let name = config["canteenName"]?.string {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.headline)
                    if let c = config["canteenCity"]?.string, !c.isEmpty { Text(c).font(.caption).foregroundColor(Theme.secondary) }
                }
            } icon: { Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.accent) }
        } else {
            Text("Wähle zuerst deine Mensa").font(.headline)
        }

        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
            TextField("Mensa oder Stadt, z. B. OTH Regensburg", text: $query)
                .disableAutocorrection(true)
            if searching { ProgressView() }
        }
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count >= 3 else { results = []; return }
            try? await Task.sleep(nanoseconds: 450_000_000)   // erst tippen lassen
            if Task.isCancelled { return }
            searching = true
            let r = await MensaService.shared.search(q)
            if !Task.isCancelled { results = r; note = r.isEmpty ? "Keine Mensa mit aktuellem Plan gefunden" : nil }
            searching = false
        }

        Button {
            Task {
                locating = true; note = nil
                if let loc = await LocationProvider.shared.current() {
                    query = ""
                    results = await MensaService.shared.nearby(loc)
                    if results.isEmpty { note = "In 15 km keine Mensa mit aktuellem Plan" }
                } else {
                    note = LocationProvider.shared.denied ? "Standortzugriff ist aus – erlauben in Einstellungen › Datenschutz › Ortungsdienste › Hubert." : "Standort gerade nicht verfügbar"
                }
                locating = false
            }
        } label: {
            HStack {
                Label("Mensen in der Nähe", systemImage: "location.fill")
                if locating { Spacer(); ProgressView() }
            }
        }

        ForEach(results) { m in
            Button {
                config["canteen"] = .number(Double(m.id))
                config["canteenName"] = .string(m.name)
                config["canteenCity"] = .string(m.city ?? "")
                results = []; query = ""
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.name).foregroundColor(.primary)
                    Text([m.city, m.address].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                }
            }
        }
        if let n = note { Text(n).font(.caption).foregroundColor(Theme.secondary) }

        VStack(alignment: .leading, spacing: 6) {
            Text("Ich bin").font(.subheadline.weight(.semibold))
            Picker("Ich bin", selection: roleBinding) {
                Text("Studierende/r").tag("students"); Text("Bedienstete/r").tag("employees"); Text("Gast").tag("others")
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 6) {
            Text("Ernährung").font(.subheadline.weight(.semibold))
            Picker("Ernährung", selection: dietBinding) {
                Text("Alles").tag("alle"); Text("Vegetarisch").tag("vegetarisch"); Text("Vegan").tag("vegan")
            }
            .pickerStyle(.segmented)
            Text("Bei vegetarisch oder vegan zeigt Hubert nur passende Gerichte.").font(.caption).foregroundColor(Theme.secondary)
        }
        .padding(.vertical, 4)
        .alert("Auch in der Küche übernehmen?", isPresented: $askKitchen) {
            Button("Übernehmen") { DietPreference.kitchen = DietPreference.kitchenValue(MensaBucket.diet(config)) }
            Button("Nur für die Mensa", role: .cancel) {}
        } message: {
            Text(MensaBucket.diet(config) == "alle"
                 ? "Die Küche zeigt dann wieder alle Rezepte."
                 : "Die Küche filtert Rezepte dann auf diesem Gerät von Anfang an nach „\(DietPreference.kitchenValue(MensaBucket.diet(config)))“ – jederzeit im Filter änderbar.")
        }
    }
}
