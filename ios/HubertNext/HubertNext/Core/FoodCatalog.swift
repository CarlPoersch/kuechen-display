import Foundation

// Lebensmittel-Katalog für den Vorrat: Bausteine zum schnellen Hinzufügen und
// Abgleich Vorrat ↔ Rezept über Oberbegriffe und Sorten.
// Die Daten stehen in FoodCatalogData.swift (erzeugt von tools/vorrat/katalog.py).
// Die Regeln hier müssen zu katalog.py passen – dort lassen sie sich testen.

struct FoodGroup {
    let name: String
    let place: String
    let swap: Bool          // Sorten untereinander austauschbar (Spaghetti ↔ Tagliatelle)
    let also: [String]      // weitere Namen für den Oberbegriff
    let sorts: [String]
}

struct FoodCategory {
    let name: String
    let place: String
    let also: [String]      // Oberbegriffe für die ganze Kategorie („Käse“, „Fleisch“)
    let groups: [FoodGroup]
}

/// Was ein Name im Katalog ist. group == nil: Oberbegriff der Kategorie, sort == nil: Oberbegriff der Gruppe.
struct FoodIdent: Equatable {
    let cat: Int
    let group: Int?
    let sort: String?
}

/// Ein Name, fertig zerlegt für den Abgleich („Milch oder Haferdrink“ → zwei Alternativen)
struct FoodKey {
    struct Alt { let text: String; let id: FoodIdent? }
    let text: String
    let alts: [Alt]
}

enum FoodCatalog {
    private struct Term {
        let words: [String]
        let length: Int
        let id: FoodIdent
    }

    private static let terms: [Term] = {
        var t: [Term] = []
        func add(_ s: String, _ id: FoodIdent) {
            let w = FoodCatalog.words(s)
            if !w.isEmpty { t.append(Term(words: w, length: s.count, id: id)) }
        }
        for (ci, c) in FoodCatalog.categories.enumerated() {
            for a in c.also { add(a, FoodIdent(cat: ci, group: nil, sort: nil)) }
            for (gi, g) in c.groups.enumerated() {
                add(g.name, FoodIdent(cat: ci, group: gi, sort: nil))
                for a in g.also { add(a, FoodIdent(cat: ci, group: gi, sort: nil)) }
                for s in g.sorts { add(s, FoodIdent(cat: ci, group: gi, sort: s)) }
            }
        }
        return t
    }()

    // Kandidaten nach erstem und letztem Buchstaben des letzten Worts (spart Vergleiche auf dem alten iPad)
    private static let byFirst: [Character: [Int]] = FoodCatalog.index { $0.first }
    private static let byLast: [Character: [Int]] = FoodCatalog.index { $0.last }

    private static func index(_ pick: (String) -> Character?) -> [Character: [Int]] {
        var d: [Character: [Int]] = [:]
        for (i, t) in terms.enumerated() { if let w = t.words.last, let c = pick(w) { d[c, default: []].append(i) } }
        return d
    }

    // MARK: Text zerlegen

    /// klein, ohne Zusätze nach Komma/Klammer
    static func cut(_ s: String) -> String {
        var t = s.lowercased()
        if let i = t.firstIndex(where: { $0 == "," || $0 == "(" }) { t = String(t[..<i]) }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Einfache Grundform: Zwiebeln → zwiebel, Tomaten/Tomate → tomat
    static func stem(_ w: String) -> String {
        for suf in ["en", "n", "e", "s"] where w.hasSuffix(suf) && w.count - suf.count >= 4 {
            return String(w.dropLast(suf.count))
        }
        return w
    }

    static func words(_ s: String) -> [String] {
        cut(s).split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "/" }).map { stem(String($0)) }
    }

    /// „zehen“, „schoten“, „filets“ … hinter einem Lebensmittel ändern nichts an der Sache
    private static func portionRest(_ rest: String) -> Bool {
        for link in ["", "en", "n", "s", "e"] where link.isEmpty || rest.hasPrefix(link) {
            let r = String(rest.dropFirst(link.count))
            if !r.isEmpty && (portionWords.contains(r) || portionWords.contains(stem(r))) { return true }
        }
        return false
    }

    /// 0 = kein Treffer, 2 = gleiches Wort, 1 = Wortende („Blattspinat“) oder Portion („Knoblauchzehen“)
    private static func wordHit(_ w: String, _ t: String) -> Int {
        if w == t { return 2 }
        guard t.count >= 4 else { return 0 }
        if w.hasSuffix(t) { return 1 }
        if w.hasPrefix(t) && portionRest(String(w.dropFirst(t.count))) { return 1 }
        return 0
    }

    // MARK: Einordnen

    private static let lock = NSLock()
    private static var cache: [String: FoodIdent?] = [:]

    /// Längster passender Katalogname gewinnt („Reisnudeln“ schlägt „Reis“)
    static func ident(_ text: String) -> FoodIdent? {
        let k = cut(text)
        lock.lock()
        if let hit = cache[k] { lock.unlock(); return hit }
        lock.unlock()

        let W = words(k)
        var best: FoodIdent?
        var score = 0
        var bestTerm = Int.max          // bei Gleichstand gewinnt der frühere Katalogeintrag (wie in katalog.py)
        for (j, w) in W.enumerated() {
            var cands: [Int] = []
            if let f = w.first { cands += byFirst[f] ?? [] }
            if let l = w.last { cands += byLast[l] ?? [] }
            for ti in cands {
                let t = terms[ti]
                let n = t.words.count
                let i = j - n + 1
                guard i >= 0 else { continue }
                var ok = true
                for m in 0..<(n - 1) where W[i + m] != t.words[m] { ok = false; break }
                guard ok else { continue }
                let h = wordHit(w, t.words[n - 1])
                guard h > 0 else { continue }
                let sc = t.length * 10 + (h == 2 ? 5 : 0)
                if sc > score || (sc == score && ti < bestTerm) { best = t.id; score = sc; bestTerm = ti }
            }
        }
        lock.lock(); cache[k] = .some(best); lock.unlock()
        return best
    }

    // MARK: Abgleich

    private static func fits(_ p: FoodIdent, _ i: FoodIdent) -> Bool {
        guard p.cat == i.cat else { return false }
        guard let pg = p.group, let ig = i.group else { return true }          // Oberbegriff der Kategorie
        guard pg == ig else { return false }
        guard let ps = p.sort, let isort = i.sort, ps != isort else { return true }   // Oberbegriff oder gleiche Sorte
        return categories[p.cat].groups[pg].swap
    }

    private static func alternatives(_ k: String) -> [String] {
        k.components(separatedBy: " oder ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static var keyCache: [String: FoodKey] = [:]

    /// Vorbereiteter Name für den Abgleich (zwischengespeichert, damit die Rezeptliste flüssig bleibt)
    static func key(_ name: String) -> FoodKey {
        lock.lock()
        if let k = keyCache[name] { lock.unlock(); return k }
        lock.unlock()
        let c = cut(name)
        let k = FoodKey(text: c, alts: alternatives(c).map { FoodKey.Alt(text: $0, id: ident($0)) })
        lock.lock(); keyCache[name] = k; lock.unlock()
        return k
    }

    /// Zählt der Vorrats-Eintrag für die Rezept-Zutat? („Nudeln“ ↔ „Tagliatelle“, „Milch“ ↔ „Milch oder Haferdrink“)
    static func matches(_ p: FoodKey, _ i: FoodKey) -> Bool {
        guard !p.text.isEmpty, !i.text.isEmpty else { return false }
        if p.text == i.text { return true }
        for pa in p.alts {
            for ia in i.alts {
                if let a = pa.id, let b = ia.id {
                    if fits(a, b) { return true }
                } else if pa.id == nil && ia.id == nil && (ia.text.contains(pa.text) || pa.text.contains(ia.text)) {
                    return true                                   // beides unbekannt: einfacher Textvergleich
                }
            }
        }
        return false
    }

    static func matches(pantry: String, ingredient: String) -> Bool {
        matches(key(pantry), key(ingredient))
    }

    // MARK: Bausteine

    /// Standard-Ort für einen Namen aus dem Katalog
    static func place(for name: String) -> String {
        guard let id = ident(name) else { return "Vorrat" }
        let c = categories[id.cat]
        return id.group.map { c.groups[$0].place } ?? c.place
    }
}
