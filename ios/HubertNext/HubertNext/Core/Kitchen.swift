import Foundation
import SwiftUI
import Combine
import CryptoKit

// ============================================================
// Küche: Daten und Logik.
//  - Rezepte: die JSON-Dateien aus dem Repo (GitHub Pages), auf dem Gerät
//    zwischengespeichert → funktionieren auch offline.
//  - Einkauf, Vorrat, Wochenplan, Bewertungen: Supabase, gemeinsam im Haushalt.
//    Änderungen sind sofort lokal sichtbar und werden im Hintergrund gespeichert.
//    Abgleich mit den anderen Geräten alle 15 s, solange die Küche sichtbar ist.
// ============================================================

// MARK: Rezepte

struct RecipeSummary: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let cuisine: String?
    let servings: Int?
    let time: String?
    let airfryer: Bool?
    let ing: [String]?
    /// Herkunft bei eigenen Rezepten: "Eigenes" oder Name des Haushalts (Familien-Kochbuch)
    var owner: String? = nil

    enum CodingKeys: String, CodingKey { case id, title, icon, cuisine, servings, time, airfryer, ing }

    /// Minuten aus "ca. 30 Min." (für den Filter "Schnell")
    var minutes: Int? {
        guard let t = time, let m = t.range(of: #"\d+"#, options: .regularExpression) else { return nil }
        return Int(t[m])
    }
}

struct Recipe: Codable, Identifiable {
    struct Ingredient: Codable, Hashable { var amount: String?; var name: String; var group: String? = nil }
    struct Step: Codable, Hashable { var text: String; var minutes: Double? = nil }
    var id: String
    var title: String
    var icon: String
    var cuisine: String?
    var servings: Int?
    var time: String?
    var ingredients: [Ingredient]
    var steps: [Step]
    var airfryer: Bool?
    var source: String? = nil     // Link, falls importiert

    var isOwn: Bool { id.hasPrefix("u-") }

    init(id: String, title: String, icon: String, cuisine: String?, servings: Int?, time: String?,
         ingredients: [Ingredient], steps: [Step], airfryer: Bool?, source: String? = nil) {
        self.id = id; self.title = title; self.icon = icon; self.cuisine = cuisine; self.servings = servings
        self.time = time; self.ingredients = ingredients; self.steps = steps; self.airfryer = airfryer; self.source = source
    }

    enum CodingKeys: String, CodingKey { case id, title, icon, cuisine, servings, time, ingredients, steps, airfryer, source }

    /// In den Rezeptdateien stehen Gruppen als eigene Einträge ({"group": "Dip"}) vor ihren Zutaten.
    /// Beim Lesen wird daraus: jede Zutat kennt ihre Gruppe, die Überschrift-Einträge fallen weg.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        icon = (try? c.decode(String.self, forKey: .icon)) ?? "🍽️"
        cuisine = try c.decodeIfPresent(String.self, forKey: .cuisine)
        servings = try c.decodeIfPresent(Int.self, forKey: .servings)
        time = try c.decodeIfPresent(String.self, forKey: .time)
        steps = (try? c.decode([Step].self, forKey: .steps)) ?? []
        airfryer = try c.decodeIfPresent(Bool.self, forKey: .airfryer)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        struct Raw: Decodable { let amount: String?; let name: String?; let group: String? }
        var group: String?
        var out: [Ingredient] = []
        for r in (try? c.decode([Raw].self, forKey: .ingredients)) ?? [] {
            if let n = r.name, !n.isEmpty {
                out.append(Ingredient(amount: r.amount, name: n, group: r.group ?? group))
            } else if let g = r.group {
                group = g
            }
        }
        ingredients = out
    }

    var baseServings: Int { max(1, servings ?? 2) }
}

// MARK: Mengen umrechnen (Portionen)

enum Amount {
    private static let fractions: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3]
    private static let pattern = try! NSRegularExpression(
        pattern: #"^(\d+(?:[.,]\d+)?)?(?:\s*([½¼¾⅓⅔]))?(?:\s*[–-]\s*(\d+(?:[.,]\d+)?))?(.*)$"#)

    /// "1½ EL" × 2 → "3 EL"; "1–2 Chilis" × 2 → "2–4 Chilis"; Text ohne Zahl bleibt
    static func scale(_ text: String?, _ factor: Double) -> String {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return "" }
        guard abs(factor - 1) > 0.001 else { return text }
        let ns = text as NSString
        guard let m = pattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return text }
        func group(_ i: Int) -> String? {
            let r = m.range(at: i); return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        let whole = group(1), frac = group(2)
        guard whole != nil || frac != nil else { return text }
        let n = (whole.map { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 } ?? 0)
            + (frac.flatMap { $0.first }.flatMap { fractions[$0] } ?? 0)
        var out = format(n * factor)
        if let n2 = group(3), let v = Double(n2.replacingOccurrences(of: ",", with: ".")) { out += "–" + format(v * factor) }
        return out + (group(4) ?? "")
    }

    /// Schöne Zahl: Brüche bei kleinen Mengen, sonst gerundet
    static func format(_ v: Double) -> String {
        if v >= 20 { return String(Int((v / 5).rounded() * 5)) }
        if v >= 10 { return String(Int(v.rounded())) }
        let whole = Int(v), rest = v - Double(whole)
        let marks: [(Double, String)] = [(0, ""), (0.25, "¼"), (1.0 / 3, "⅓"), (0.5, "½"), (2.0 / 3, "⅔"), (0.75, "¾"), (1, "")]
        if let near = marks.min(by: { abs($0.0 - rest) < abs($1.0 - rest) }), abs(near.0 - rest) < 0.06 {
            if near.0 == 1 { return String(whole + 1) }
            return whole == 0 ? (near.1.isEmpty ? "0" : near.1) : "\(whole)" + near.1
        }
        return String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: Airfryer

enum Airfryer {
    /// Faustregel Backofen → Airfryer: 20 °C weniger, 20 % kürzer
    static func fromOven(celsius: Int, minutes: Int) -> (celsius: Int, minutes: Int) {
        (max(80, celsius - 20), max(1, Int((Double(minutes) * 0.8).rounded())))
    }

    /// Hinweis zu einem Rezeptschritt, falls er im Airfryer anders geht
    static func hint(for step: Recipe.Step, recipeIsAirfryer: Bool) -> String? {
        guard !recipeIsAirfryer else { return nil }
        let t = step.text.lowercased()
        if t.contains("frittier") || t.contains("ausbacken") || (t.contains("öl") && t.contains("°c")) {
            return "Im Airfryer: rundum mit Öl einsprühen, 200 °C, ca. 10–14 Min., nach der Hälfte wenden"
        }
        if t.contains("ofen") || t.contains("backofen"),
           let r = step.text.range(of: #"\d{3}"#, options: .regularExpression), let c = Int(step.text[r]) {
            let a = fromOven(celsius: c, minutes: Int(step.minutes ?? 20))
            return "Im Airfryer: \(a.celsius) °C, ca. \(a.minutes) Min."
        }
        return nil
    }

    /// Spickzettel: Gruppe, Lebensmittel, °C, Minuten, Tipp
    static let table: [(String, String, String, String, String)] = [
        ("TK & Fertig", "TK-Pommes", "200", "15–18", "Alle 5 Min. schütteln"),
        ("TK & Fertig", "TK-Kroketten", "200", "10–12", "Nach der Hälfte wenden"),
        ("TK & Fertig", "Chicken Nuggets (TK)", "200", "10–12", "In einer Lage"),
        ("TK & Fertig", "Fischstäbchen (TK)", "200", "8–10", "Nach der Hälfte wenden"),
        ("TK & Fertig", "Pizza (TK, klein)", "180", "8–10", "Auf Backpapier"),
        ("TK & Fertig", "Gyoza / Dumplings (TK)", "190", "10–12", "Vorher mit Öl benetzen"),
        ("TK & Fertig", "Frühlingsrollen (TK)", "190", "10–12", "Nach der Hälfte wenden"),
        ("TK & Fertig", "Croissants / Aufbackbrötchen", "170", "6–10", "Nicht stapeln"),
        ("TK & Fertig", "Brötchen aufbacken (Vortag)", "180", "3–4", "Kurz mit Wasser besprühen"),
        ("Fleisch & Fisch", "Hähnchenbrust", "180", "15–18", "Kerntemperatur 74 °C"),
        ("Fleisch & Fisch", "Hähnchenschenkel", "190", "22–25", "Hautseite zuletzt oben"),
        ("Fleisch & Fisch", "Chicken Wings", "180", "20 + 5 bei 200 °C", "Mit Backpulver knuspriger"),
        ("Fleisch & Fisch", "Bratwurst", "190", "10–12", "Nach der Hälfte wenden"),
        ("Fleisch & Fisch", "Frikadellen", "180", "12–14", "Nach der Hälfte wenden"),
        ("Fleisch & Fisch", "Schnitzel, paniert", "190", "10–12", "Mit etwas Öl einsprühen"),
        ("Fleisch & Fisch", "Lachsfilet", "190", "8–10", "Innen noch leicht glasig"),
        ("Fleisch & Fisch", "Speck", "180", "6–8", "Backpapier gegen Fettspritzer"),
        ("Gemüse & Beilagen", "Kartoffelspalten (frisch)", "190", "18–22", "Vorher einweichen, gut trocknen"),
        ("Gemüse & Beilagen", "Pommes (frisch)", "180 → 200", "20 + 5", "Siehe Rezept „Knusprige Pommes“"),
        ("Gemüse & Beilagen", "Süßkartoffel-Pommes", "190", "15–18", "Mit Stärke bestäuben"),
        ("Gemüse & Beilagen", "Ganze Kartoffel", "200", "35–45", "Einstechen, mit Öl und Salz"),
        ("Gemüse & Beilagen", "Brokkoli", "190", "7–9", "Mit Öl und Salz, Spitzen werden knusprig"),
        ("Gemüse & Beilagen", "Rosenkohl, halbiert", "180", "12–15", "Schnittfläche nach unten"),
        ("Gemüse & Beilagen", "Paprika, Zucchini, Zwiebel", "200", "10–12", "Einmal schütteln"),
        ("Gemüse & Beilagen", "Halloumi", "200", "6–8", "Dicke Scheiben"),
        ("Gemüse & Beilagen", "Tofu-Würfel", "200", "12–15", "Mit Stärke bestäuben"),
        ("Gemüse & Beilagen", "Kichererbsen (Snack)", "200", "12–15", "Gut trocknen, mit Gewürzen"),
        ("Snacks & Sonstiges", "Eier, wachsweich", "150", "9–10", "Danach in Eiswasser"),
        ("Snacks & Sonstiges", "Eier, hart", "150", "13–15", "Danach in Eiswasser"),
        ("Snacks & Sonstiges", "Nüsse rösten", "160", "4–6", "Wird schnell zu dunkel"),
        ("Snacks & Sonstiges", "Pizza aufwärmen", "180", "3–4", "Boden wird wieder knusprig"),
        ("Snacks & Sonstiges", "Pommes aufwärmen", "200", "3–4", "Besser als Mikrowelle"),
    ]
}

// MARK: Gemeinsame Daten (Supabase)

struct KitchenItem: Codable, Identifiable, Equatable {
    var id: String
    var householdId: String
    var kind: String          // "shop" oder "pantry"
    var name: String
    var amount: String = ""
    var place: String = ""
    var mhd: String?          // "yyyy-MM-dd"
    var done: Bool = false
    var recipe: String = ""
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, name, amount, place, mhd, done, recipe
        case householdId = "household_id", createdAt = "created_at"
    }

    // mhd immer mitschicken (auch leer), damit ein gelöschtes Datum auch auf dem Server verschwindet
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(householdId, forKey: .householdId)
        try c.encode(kind, forKey: .kind); try c.encode(name, forKey: .name)
        try c.encode(amount, forKey: .amount); try c.encode(place, forKey: .place)
        try c.encode(mhd, forKey: .mhd); try c.encode(done, forKey: .done); try c.encode(recipe, forKey: .recipe)
        if let created = createdAt { try c.encode(created, forKey: .createdAt) }
    }

    var mhdDate: Date? { mhd.flatMap { KitchenStore.day.date(from: $0) } }
    /// Tage bis zum Mindesthaltbarkeitsdatum (negativ = abgelaufen)
    var daysLeft: Int? { mhdDate.map { Fmt.dayDiff($0) } }
}

struct PlanEntry: Codable, Identifiable, Equatable {
    var id: String
    var householdId: String
    var day: String           // "yyyy-MM-dd"
    var recipeId: String
    var portions: Int
    enum CodingKeys: String, CodingKey {
        case id, day, portions
        case householdId = "household_id", recipeId = "recipe_id"
    }
}

struct RecipeMeta: Codable, Equatable {
    var householdId: String
    var recipeId: String
    var rating: Int?
    var note: String = ""
    var cookedCount: Int = 0
    var lastCooked: String?
    enum CodingKeys: String, CodingKey {
        case rating, note
        case householdId = "household_id", recipeId = "recipe_id", cookedCount = "cooked_count", lastCooked = "last_cooked"
    }
    var lastCookedDate: Date? { Fmt.date(lastCooked) }
}

struct OwnRecipe: Codable, Equatable {
    var id: String            // uuid in der Datenbank
    var householdId: String
    var data: Recipe
    enum CodingKeys: String, CodingKey { case id, data, householdId = "household_id" }
    static func == (a: OwnRecipe, b: OwnRecipe) -> Bool { a.id == b.id && a.data.title == b.data.title }
}

struct Alias: Codable {
    var householdId: String
    var key: String
    var name: String
    enum CodingKeys: String, CodingKey { case key, name, householdId = "household_id" }
}

struct Cookbook: Decodable, Equatable {
    let sourceId: String
    let name: String
    enum CodingKeys: String, CodingKey { case name, sourceId = "source_id" }
}

struct CookedEvent: Codable, Equatable {
    var id: String
    var householdId: String
    var recipeId: String
    var cookedAt: String
    enum CodingKeys: String, CodingKey { case id, householdId = "household_id", recipeId = "recipe_id", cookedAt = "cooked_at" }
    var date: Date { Fmt.date(cookedAt) ?? Date.distantPast }
}

// MARK: Speicher

final class KitchenStore: ObservableObject {
    static let shared = KitchenStore()
    static let recipeBase = URL(string: "https://carlpoersch.github.io/kuechen-display/apps/rezepte/data/")!
    static let places = ["Kühlschrank", "Gefrierfach", "Vorrat"]
    static let day: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    @Published private(set) var catalog: [RecipeSummary] = []      // Rezepte aus dem Repo
    @Published private(set) var own: [OwnRecipe] = []               // eigene + aus Familien-Kochbüchern
    @Published private(set) var followed: [Cookbook] = []
    @Published private(set) var cooked: [CookedEvent] = []           // für die Statistik
    @Published private(set) var aliases: [String: String] = [:]      // gelernte Vorratsnamen (Kassenzettel, Barcode)
    @Published private(set) var details: [String: Recipe] = [:]
    @Published private(set) var items: [KitchenItem] = []
    @Published private(set) var plan: [PlanEntry] = []
    @Published private(set) var meta: [String: RecipeMeta] = [:]
    @Published private(set) var synced: Date?
    @Published var failed = false

    private(set) var household: String?
    private let api = SupabaseClient.shared
    private var syncing = false

    init() { restore() }

    // MARK: Laden

    /// Rezepte (Übersicht) laden – zuerst aus dem Zwischenspeicher, dann frisch
    func loadRecipes() async {
        if catalog.isEmpty, let d = try? Data(contentsOf: cacheFile("index.json")),
           let list = try? JSONDecoder().decode([RecipeSummary].self, from: d) { catalog = list }
        guard let (data, resp) = try? await URLSession.shared.data(from: Self.recipeBase.appendingPathComponent("index.json")),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let list = try? JSONDecoder().decode([RecipeSummary].self, from: data) else { return }
        catalog = list.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        try? data.write(to: cacheFile("index.json"))
    }

    /// Alle Rezepte: eigene und Familien-Kochbuch zuerst, dann die Sammlung
    var recipes: [RecipeSummary] {
        own.map { o in
            RecipeSummary(id: o.data.id, title: o.data.title, icon: o.data.icon, cuisine: o.data.cuisine,
                          servings: o.data.servings, time: o.data.time, airfryer: o.data.airfryer,
                          ing: o.data.ingredients.map { $0.name },
                          owner: o.householdId == household ? "Eigenes" : (followed.first { $0.sourceId == o.householdId }?.name ?? "Familie"))
        }.sorted { $0.title.localizedCompare($1.title) == .orderedAscending } + catalog
    }

    /// Ein ganzes Rezept (mit Mengen und Schritten)
    func recipe(_ id: String) async -> Recipe? {
        if let o = own.first(where: { $0.data.id == id }) { return o.data }
        if let r = details[id] { return r }
        let file = cacheFile("r-" + id + ".json")
        if let d = try? Data(contentsOf: file), let r = try? JSONDecoder().decode(Recipe.self, from: d) {
            details[id] = r
            Task { await refreshRecipe(id) }
            return r
        }
        await refreshRecipe(id)
        return details[id]
    }

    private func refreshRecipe(_ id: String) async {
        guard let (data, resp) = try? await URLSession.shared.data(from: Self.recipeBase.appendingPathComponent(id + ".json")),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let r = try? JSONDecoder().decode(Recipe.self, from: data) else { return }
        details[id] = r
        try? data.write(to: cacheFile("r-" + id + ".json"))
    }

    func summary(_ id: String) -> RecipeSummary? { recipes.first { $0.id == id } }

    /// Abgleich mit dem Server (Einkauf, Vorrat, Plan, Bewertungen)
    func sync(household: String?, force: Bool = false) async {
        guard let h = household else { return }
        self.household = h
        if syncing { return }
        if !force, let t = synced, Date().timeIntervalSince(t) < 10 { return }
        syncing = true; defer { syncing = false }
        do {
            let hid = "eq." + h
            async let i: [KitchenItem] = api.select("kitchen_items", ["household_id": hid, "order": "created_at"])
            let from = Self.day.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)
            async let p: [PlanEntry] = api.select("kitchen_plan", ["household_id": hid, "day": "gte." + from, "order": "day,created_at"])
            async let m: [RecipeMeta] = api.select("kitchen_meta", ["household_id": hid])
            let (ii, pp, mm) = try await (i, p, m)
            items = ii; plan = pp; meta = Dictionary(uniqueKeysWithValues: mm.map { ($0.recipeId, $0) })
            // Runde 2 (eigene Rezepte, Kochbuch, Statistik) – eigener Block: fehlt etwas, läuft der Rest weiter
            do {
                let year = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-400 * 86400))
                async let o: [OwnRecipe] = api.select("kitchen_recipes", ["order": "created_at"])
                async let c: [CookedEvent] = api.select("kitchen_cooked", ["household_id": hid, "cooked_at": "gte." + year])
                async let f: [Cookbook] = api.rpc("followed_cookbooks", ["p_household": h])
                async let a: [Alias] = api.select("kitchen_aliases", ["household_id": hid])
                let (oo, cc, ff, aa) = try await (o, c, f, a)
                own = oo; cooked = cc; followed = ff
                aliases = Dictionary(aa.map { ($0.key, $0.name) }, uniquingKeysWith: { a, _ in a })
            } catch { print("Küche Runde 2:", error) }
            synced = Date(); failed = false
            save()
        } catch {
            failed = true
            print("Küche:", error)
        }
    }

    // MARK: Einkauf und Vorrat

    var shop: [KitchenItem] { items.filter { $0.kind == "shop" } }
    var pantry: [KitchenItem] { items.filter { $0.kind == "pantry" } }

    func add(_ kind: String, name: String, amount: String = "", place: String = "", recipe: String = "", mhd: String? = nil) {
        guard let h = household else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let it = KitchenItem(id: UUID().uuidString.lowercased(), householdId: h, kind: kind, name: clean, amount: amount,
                             place: place, mhd: mhd, recipe: recipe, createdAt: ISO8601DateFormatter().string(from: Date()))
        items.append(it)
        write { try await self.api.upsert("kitchen_items", [it]) }
    }

    func update(_ it: KitchenItem) {
        guard let i = items.firstIndex(where: { $0.id == it.id }) else { return }
        items[i] = it
        write { try await self.api.upsert("kitchen_items", [it]) }
    }

    /// Abhaken auf der Einkaufsliste = eingekauft → kommt automatisch in den Vorrat.
    /// Der Vorrats-Eintrag merkt sich, woher er kam ("shop:<id>"), damit Zurückhaken ihn wieder entfernt.
    func toggle(_ it: KitchenItem) {
        var c = it; c.done.toggle(); update(c)
        guard it.kind == "shop" else { return }
        let marker = "shop:" + it.id
        if c.done {
            if !inPantry(it.name) { add("pantry", name: it.name, place: "Vorrat", recipe: marker) }
        } else {
            for p in pantry where p.recipe == marker { delete(p) }
        }
    }

    func delete(_ it: KitchenItem) {
        items.removeAll { $0.id == it.id }
        write { try await self.api.delete("kitchen_items", ["id": "eq." + it.id]) }
    }

    func clearDone() {
        let done = shop.filter { $0.done }
        items.removeAll { $0.kind == "shop" && $0.done }
        for it in done { write { try await self.api.delete("kitchen_items", ["id": "eq." + it.id]) } }
    }

    /// Eingekauft → in den Vorrat
    func moveToPantry(_ it: KitchenItem) {
        delete(it)
        if !inPantry(it.name) { add("pantry", name: it.name, place: "Vorrat") }
    }

    /// Ist etwas mit diesem Namen im Vorrat? ("Knoblauchzehen" passt zu "Knoblauch")
    func inPantry(_ ingredient: String) -> Bool {
        let n = Self.key(ingredient)
        guard !n.isEmpty else { return false }
        return pantry.contains { p in let k = Self.key(p.name); return !k.isEmpty && (n.contains(k) || k.contains(n)) }
    }

    private func onList(_ ingredient: String) -> Bool {
        let n = Self.key(ingredient)
        return shop.contains { !$0.done && Self.key($0.name) == n }
    }

    /// Vergleichsschlüssel: klein, ohne Zusätze nach Komma/Klammer
    static func key(_ s: String) -> String {
        var t = s.lowercased()
        if let i = t.firstIndex(where: { $0 == "," || $0 == "(" }) { t = String(t[..<i]) }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Hat man immer da – kommt nie auf die Einkaufsliste
    private static let basics: Set<String> = ["salz", "pfeffer", "wasser", "salz und pfeffer", "eiswasser", "heißes wasser"]

    /// Fehlende Zutaten eines Rezepts auf die Einkaufsliste. Rückgabe: Anzahl neu
    @discardableResult
    func addMissing(_ r: Recipe, portions: Int) -> Int {
        let factor = Double(portions) / Double(r.baseServings)
        var n = 0
        for ing in r.ingredients {
            let k = Self.key(ing.name)
            if Self.basics.contains(k) || inPantry(ing.name) || onList(ing.name) { continue }
            add("shop", name: ing.name.components(separatedBy: ",")[0], amount: Amount.scale(ing.amount, factor), recipe: r.title)
            n += 1
        }
        return n
    }

    /// Einkaufsliste aus dem Wochenplan (heute und die nächsten 6 Tage)
    func shoppingFromPlan() async -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let week = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        var n = 0
        for e in plan {
            guard let d = Self.day.date(from: e.day), d >= today, d < week, let r = await recipe(e.recipeId) else { continue }
            n += addMissing(r, portions: e.portions)
        }
        return n
    }

    // MARK: Wochenplan

    func planned(on date: Date) -> [PlanEntry] { plan.filter { $0.day == Self.day.string(from: date) } }

    func addToPlan(_ recipeId: String, on date: Date, portions: Int) {
        guard let h = household else { return }
        let e = PlanEntry(id: UUID().uuidString.lowercased(), householdId: h, day: Self.day.string(from: date),
                          recipeId: recipeId, portions: portions)
        plan.append(e)
        write { try await self.api.upsert("kitchen_plan", [e]) }
    }

    func removeFromPlan(_ e: PlanEntry) {
        plan.removeAll { $0.id == e.id }
        write { try await self.api.delete("kitchen_plan", ["id": "eq." + e.id]) }
    }

    func movePlan(_ e: PlanEntry, to date: Date) {
        guard let i = plan.firstIndex(where: { $0.id == e.id }) else { return }
        plan[i].day = Self.day.string(from: date)
        let c = plan[i]
        write { try await self.api.upsert("kitchen_plan", [c]) }
    }

    func setPortions(_ e: PlanEntry, _ p: Int) {
        guard let i = plan.firstIndex(where: { $0.id == e.id }) else { return }
        plan[i].portions = max(1, min(20, p))
        let c = plan[i]
        write { try await self.api.upsert("kitchen_plan", [c]) }
    }

    // MARK: Bewertung, Notiz, Kochverlauf

    func metaFor(_ id: String) -> RecipeMeta {
        meta[id] ?? RecipeMeta(householdId: household ?? "", recipeId: id)
    }

    func setRating(_ id: String, _ stars: Int?) { changeMeta(id) { $0.rating = stars } }
    func setNote(_ id: String, _ note: String) { changeMeta(id) { $0.note = note } }
    func markCooked(_ id: String) {
        changeMeta(id) { $0.cookedCount += 1; $0.lastCooked = ISO8601DateFormatter().string(from: Date()) }
        guard let h = household else { return }
        let e = CookedEvent(id: UUID().uuidString.lowercased(), householdId: h, recipeId: id,
                            cookedAt: ISO8601DateFormatter().string(from: Date()))
        cooked.append(e)
        write { try await self.api.upsert("kitchen_cooked", [e]) }
    }

    // MARK: Eigene Rezepte und Familien-Kochbuch

    /// Speichern (neu oder geändert). Rückgabe: die Rezept-ID ("u-…")
    @discardableResult
    func saveOwn(_ r: Recipe) -> String? {
        guard let h = household else { return nil }
        var r = r
        let uuid = r.isOwn ? String(r.id.dropFirst(2)) : UUID().uuidString.lowercased()
        r.id = "u-" + uuid
        let o = OwnRecipe(id: uuid, householdId: h, data: r)
        if let i = own.firstIndex(where: { $0.id == uuid }) { own[i] = o } else { own.append(o) }
        write { try await self.api.upsert("kitchen_recipes", [o]) }
        return r.id
    }

    func deleteOwn(_ recipeId: String) {
        let uuid = String(recipeId.dropFirst(2))
        own.removeAll { $0.id == uuid }
        write { try await self.api.delete("kitchen_recipes", ["id": "eq." + uuid]) }
    }

    /// Darf man dieses Rezept bearbeiten? (eigenes, nicht aus einem fremden Kochbuch)
    func isMine(_ recipeId: String) -> Bool {
        own.contains { $0.data.id == recipeId && $0.householdId == household }
    }

    func cookbookCode() async -> String? {
        guard let h = household else { return nil }
        return try? await api.rpc("my_cookbook_code", ["p_household": h])
    }

    /// Einem anderen Kochbuch folgen. Rückgabe: Name des Haushalts
    func follow(code: String) async throws -> String {
        guard let h = household else { throw APIError(status: 0, message: "Kein Haushalt") }
        let name: String = try await api.rpc("follow_cookbook", ["p_household": h, "p_code": code])
        await sync(household: h, force: true)
        return name
    }

    func unfollow(_ c: Cookbook) {
        guard let h = household else { return }
        followed.removeAll { $0.sourceId == c.sourceId }
        own.removeAll { $0.householdId == c.sourceId }
        write { try await self.api.delete("kitchen_follows", ["household_id": "eq." + h, "source_id": "eq." + c.sourceId]) }
    }

    /// Rezept von einer Webseite lesen (Server liest die Rezeptdaten der Seite)
    func importRecipe(from link: String) async throws -> Recipe {
        let data = try await api.raw("GET", "/functions/v1/kitchen/import", query: [URLQueryItem(name: "u", value: link)])
        if let err = try? JSONDecoder().decode([String: String].self, from: data), let e = err["error"] {
            throw APIError(status: 400, message: e)
        }
        return try JSONDecoder().decode(Recipe.self, from: data)
    }

    // MARK: Saubere Vorratsnamen (gelernt + Regeln)

    /// Name für eine Kassenzettel-Zeile: Gelerntes zuerst, sonst Regel-Bereinigung
    func pantryName(receipt raw: String) -> String {
        aliases[FoodNames.key(raw)] ?? FoodNames.clean(raw, extra: ingredientNames)
    }

    /// Gelernter Name für einen Barcode (falls schon einmal umbenannt)
    func pantryName(barcode code: String) -> String? { aliases["EAN " + code] }

    /// Korrektur merken – gilt ab sofort für den ganzen Haushalt
    func learn(key: String, name: String) {
        guard let h = household, !key.isEmpty else { return }
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, aliases[key] != clean else { return }
        aliases[key] = clean
        let row = Alias(householdId: h, key: key, name: clean)
        write { try await self.api.upsert("kitchen_aliases", [row]) }
    }

    /// Kurze Zutatennamen aus den Rezepten ("Knoblauchzehen", "Kokosmilch" …) als zusätzliche Lebensmittelliste
    private var ingredientNames: [String] {
        if let c = ingredientCache, c.0 == catalog.count { return c.1 }
        var seen = Set<String>(), out: [String] = []
        for r in catalog { for n in r.ing ?? [] {
            let k = Self.key(n)
            guard k.count >= 4, k.split(separator: " ").count <= 2, !seen.contains(k) else { continue }
            seen.insert(k); out.append(k.prefix(1).uppercased() + k.dropFirst())
        } }
        ingredientCache = (catalog.count, out)
        return out
    }
    private var ingredientCache: (Int, [String])?

    // MARK: Siri-Kurzbefehl

    /// Neuer Schlüssel für den Kurzbefehl. Alte Schlüssel des Haushalts werden ungültig.
    func newShortcutToken() async throws -> String {
        guard let h = household else { throw APIError(status: 0, message: "Kein Haushalt") }
        let chars = Array("abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let token = String((0..<32).map { _ in chars.randomElement()! })
        let hash = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        try await api.delete("kitchen_tokens", ["household_id": "eq." + h])
        struct Row: Encodable { let token_hash: String; let household_id: String }
        try await api.upsert("kitchen_tokens", [Row(token_hash: hash, household_id: h)])
        return token
    }

    static var shortcutURL: String { Config.supabaseURL.absoluteString + "/functions/v1/kitchen/add" }

    private func changeMeta(_ id: String, _ change: (inout RecipeMeta) -> Void) {
        guard let h = household else { return }
        var m = metaFor(id); m.householdId = h
        change(&m)
        meta[id] = m
        write { try await self.api.upsert("kitchen_meta", [m]) }
    }

    /// Rezept des Tages: jeden Tag ein anderes, bevorzugt länger nicht gekochte
    func recipeOfTheDay(_ date: Date = Date()) -> RecipeSummary? {
        guard !recipes.isEmpty else { return nil }
        let dayNo = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let fresh = recipes.filter { r in
            guard let last = meta[r.id]?.lastCookedDate else { return true }
            return Date().timeIntervalSince(last) > 14 * 86400
        }
        let pool = fresh.isEmpty ? recipes : fresh
        return pool[abs(dayNo &* 7919) % pool.count]
    }

    // MARK: Intern

    /// Speichern im Hintergrund; bei Fehler neu abgleichen, damit nichts Falsches stehen bleibt
    private func write(_ op: @escaping () async throws -> Void) {
        save()
        Task {
            do { try await op() } catch {
                print("Küche speichern:", error)
                failed = true
                await sync(household: household, force: true)
            }
        }
    }

    /// Beim Abmelden/Löschen: alles vom Haushalt vergessen (Rezeptsammlung bleibt zwischengespeichert)
    func reset() {
        items = []; plan = []; meta = [:]; own = []; followed = []; cooked = []; aliases = [:]
        household = nil; synced = nil
        try? FileManager.default.removeItem(at: cacheFile("snapshot.json"))
    }

    private struct Snapshot: Codable {
        var items: [KitchenItem]; var plan: [PlanEntry]; var meta: [RecipeMeta]; var household: String?
        var own: [OwnRecipe]? = nil
    }

    private func cacheFile(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("kitchen", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }

    private func save() {
        let s = Snapshot(items: items, plan: plan, meta: Array(meta.values), household: household, own: own)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: cacheFile("snapshot.json")) }
    }

    private func restore() {
        guard let d = try? Data(contentsOf: cacheFile("snapshot.json")),
              let s = try? JSONDecoder().decode(Snapshot.self, from: d) else { return }
        items = s.items; plan = s.plan; household = s.household; own = s.own ?? []
        meta = Dictionary(uniqueKeysWithValues: s.meta.map { ($0.recipeId, $0) })
        if let d2 = try? Data(contentsOf: cacheFile("index.json")),
           let list = try? JSONDecoder().decode([RecipeSummary].self, from: d2) {
            catalog = list.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }
}
