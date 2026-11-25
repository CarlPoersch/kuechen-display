import Foundation

// ============================================================
// Zutaten-Suche im Rezeptfilter („Mit diesen Zutaten“)
//
// Passt eine gesuchte Zutat zu einer Rezept-Zutat?
//   1. Oberbegriffe aus dem Vorrat-Katalog: „Nudeln“ findet Spaghetti, Penne …, „Käse“ jeden Käse.
//      Eine bestimmte Sorte („Spaghetti“) findet nur sich selbst – und Rezepte, die nur „Nudeln“ sagen.
//   2. Varianten: „Tomaten“ findet Cherrytomaten und passierte Tomaten (gleiches Wortende, Mehrzahl egal).
//      „Butter“ findet aber nicht „Butternut“.
//   3. Andere Namen: Sahne = Rahm, Hackfleisch = Faschiertes, Karotten = Möhren …
//
// Vorschläge beim Tippen kommen aus allen Rezept-Zutaten und den Oberbegriffen des Katalogs.
// Gezeigt wird nur, was zusammen mit den übrigen Filtern noch Rezepte ergibt – mit Anzahl.
// ============================================================

enum IngredientSearch {

    // MARK: Andere Namen (in beide Richtungen)

    private static let synonymGroups: [[String]] = [
        ["Ei", "Eier"],
        ["Sahne", "Rahm", "Schlagsahne", "Schlagrahm"],
        ["Hackfleisch", "Faschiertes", "Gehacktes", "Hack"],
        ["Karotten", "Möhren", "Mohrrüben", "Gelbe Rüben"],
        ["Kartoffeln", "Erdäpfel"],
        ["Tomaten", "Paradeiser"],
        ["Quark", "Topfen"],
        ["Brötchen", "Semmeln", "Schrippen"],
        ["Lauch", "Porree"],
        ["Frühlingszwiebeln", "Lauchzwiebeln"],
        ["Rucola", "Rauke"],
        ["Blumenkohl", "Karfiol"],
        ["Rosenkohl", "Kohlsprossen"],
        ["Meerrettich", "Kren"],
        ["Aprikosen", "Marillen"],
        ["Johannisbeeren", "Ribisel"],
        ["Pfifferlinge", "Eierschwammerl"],
        ["Aubergine", "Melanzani"],
        ["Zucchini", "Zucchetti"],
        ["Rote Bete", "Rote Beete", "Rote Rüben"],
        ["Feldsalat", "Rapunzel", "Vogerlsalat"],
        ["Kichererbsen", "Garbanzos"],
        ["Koriander", "Koriandergrün"],
        ["Schnittlauch", "Schnittlauchröllchen"],
        ["Puderzucker", "Staubzucker"],
        ["Speisestärke", "Maisstärke", "Stärke"],
        ["Natron", "Backsoda"],
    ]

    private static let synonyms: [String: [String]] = {
        var d: [String: [String]] = [:]
        for g in synonymGroups {
            let keys = g.map(norm)
            for k in keys { d[k, default: []] += keys.filter { $0 != k } }
        }
        return d
    }()

    /// klein, Grundform jedes Worts (Tomaten → tomat)
    private static func norm(_ s: String) -> String {
        FoodCatalog.words(s).joined(separator: " ")
    }

    // MARK: Passt das?

    /// Vorbereitete Suche: alle Schreibweisen (mit anderen Namen) und die Einordnung im Katalog
    struct Term {
        let display: String
        let forms: [[String]]          // je Schreibweise die Wörter in Grundform
        let ident: FoodIdent?
    }

    private static var termCache: [String: Term] = [:]

    static func term(_ s: String) -> Term {
        if let t = termCache[s] { return t }
        let base = norm(s)
        let all = [base] + (synonyms[base] ?? [])
        let t = Term(display: s,
                     forms: all.map { $0.split(separator: " ").map(String.init) }.filter { !$0.isEmpty },
                     ident: FoodCatalog.ident(s))
        termCache[s] = t
        return t
    }

    /// Wörter einer Rezept-Zutat in Grundform (zwischengespeichert – die Liste wird oft durchsucht)
    private static var wordCache: [String: [String]] = [:]
    private static func ingWords(_ ing: String) -> [String] {
        if let w = wordCache[ing] { return w }
        let w = FoodCatalog.words(ing)
        wordCache[ing] = w
        return w
    }

    /// Vorsilben, die aus der Zutat etwas anderes machen: Süßkartoffel ist keine Kartoffel,
    /// Erdnussbutter keine Butter, Kokosmilch keine Milch
    private static let otherFood: Set<String> = ["süß", "erdnuss", "kokos", "hafer", "mandel", "soja", "reis", "kakao",
                                                 "mais", "butter", "cashew", "nuss", "haselnuss", "walnuss", "sesam", "palm"]

    /// Wortvergleich: gleich, oder die gesuchte Grundform ist das Wortende („cherrytomat“ endet auf „tomat“)
    private static func wordFits(_ w: String, _ t: String) -> Bool {
        if w == t { return true }
        guard t.count >= 4, w.hasSuffix(t) else { return false }
        return !otherFood.contains(String(w.dropLast(t.count)))
    }

    /// Kommt die Schreibweise (alle Wörter, in dieser Reihenfolge, zusammenhängend) in der Zutat vor?
    private static func phraseFits(_ words: [String], _ form: [String]) -> Bool {
        guard !form.isEmpty, words.count >= form.count else { return false }
        for i in 0...(words.count - form.count) {
            var ok = true
            for (j, f) in form.enumerated() {
                let w = words[i + j]
                // Mehrwortnamen: nur das letzte Wort darf ein längeres Wort sein
                if !(j == form.count - 1 ? wordFits(w, f) : w == f) { ok = false; break }
            }
            if ok { return true }
        }
        return false
    }

    /// Passt die gesuchte Zutat zu dieser Rezept-Zutat?
    static func fits(_ t: Term, ingredient: String) -> Bool {
        let words = ingWords(ingredient)
        for f in t.forms where phraseFits(words, f) { return true }
        // Katalog: Oberbegriff findet alle Sorten; Rezept sagt nur den Oberbegriff → passt auch zur Sorte
        guard let a = t.ident else { return false }
        for alt in FoodCatalog.key(ingredient).alts {
            guard let b = alt.id, a.cat == b.cat else { continue }
            guard let ag = a.group else { return true }                  // „Käse“, „Fleisch“: ganze Kategorie
            guard let bg = b.group, bg == ag else {
                if b.group == nil { return true }                         // Rezept sagt nur „Käse“
                continue
            }
            if a.sort == nil || b.sort == nil || a.sort == b.sort { return true }
        }
        return false
    }

    /// Enthält das Rezept diese Zutat?
    static func has(_ r: RecipeSummary, _ name: String) -> Bool {
        let t = term(name)
        return (r.ing ?? []).contains { fits(t, ingredient: $0) }
    }

    // MARK: Vorschläge beim Tippen

    private static var poolCache: (Int, [String])?

    /// Alle sinnvollen Zutatennamen: Rezept-Zutaten (ohne Zusätze) + Oberbegriffe/Sorten aus dem Katalog
    static func pool(_ recipes: [RecipeSummary]) -> [String] {
        if let c = poolCache, c.0 == recipes.count { return c.1 }
        var seen = Set<String>(), out: [String] = []
        func add(_ raw: String) {
            var s = raw
            if let i = s.firstIndex(where: { $0 == "," || $0 == "(" }) { s = String(s[..<i]) }
            s = s.trimmingCharacters(in: .whitespaces)
            let k = norm(s)
            guard s.count >= 3, s.split(separator: " ").count <= 3, !seen.contains(k) else { return }
            seen.insert(k); out.append(s)
        }
        for c in FoodCatalog.categories {
            c.also.forEach(add)
            for g in c.groups { add(g.name); g.also.forEach(add); g.sorts.forEach(add) }
        }
        for g in synonymGroups { g.forEach(add) }
        for r in recipes { (r.ing ?? []).forEach(add) }
        poolCache = (recipes.count, out)
        return out
    }

    struct Suggestion: Identifiable {
        let name: String
        let count: Int
        let hint: String          // „alle Sorten“ bei Oberbegriffen
        var id: String { name }
    }

    /// Vorschläge zur Eingabe. `count`: Wie viele Rezepte bleiben mit dieser Zutat zusätzlich?
    /// Vorschläge ohne Treffer fallen weg.
    static func suggest(_ query: String, chosen: [String], recipes: [RecipeSummary],
                        count: (String) -> Int, limit: Int = 8) -> [Suggestion] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard q.count >= 1 else { return [] }
        let taken = Set(chosen.map(norm))
        var scored: [(String, Int)] = []
        for name in pool(recipes) {
            let k = name.lowercased()
            guard !taken.contains(norm(name)) else { continue }
            var s: Int
            if k == q { s = 300 }
            else if k.hasPrefix(q) { s = 200 }
            else if k.split(whereSeparator: { $0 == " " || $0 == "-" }).contains(where: { $0.hasPrefix(q) }) { s = 150 }
            else if q.count >= 3 && k.contains(q) { s = 80 }
            else { continue }
            // Katalognamen und kurze Namen zuerst („Bananen“ vor „sehr reife Bananen“)
            if FoodCatalog.ident(name) != nil { s += 25 }
            s -= min(k.count, 30)
            scored.append((name, s))
        }
        var out: [Suggestion] = []
        // Nur die besten Kandidaten zählen – das Zählen geht über alle Rezepte (iPad mini 4 schonen)
        for (name, _) in scored.sorted(by: { $0.1 > $1.1 }).prefix(limit * 2) {
            let n = count(name)
            guard n > 0 else { continue }
            // „alle Sorten“ nur bei echten Oberbegriffen (Kategorie oder Gruppe mit Sorten)
            var general = false
            if let id = FoodCatalog.ident(name), id.sort == nil {
                general = id.group.map { !FoodCatalog.categories[id.cat].groups[$0].sorts.isEmpty } ?? true
            }
            out.append(Suggestion(name: name, count: n, hint: general ? "alle Sorten" : ""))
            if out.count == limit { break }
        }
        return out
    }
}
