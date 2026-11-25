import Foundation
import Combine

// ============================================================
// Nährwerte (Richtwerte pro Portion)
//  - Rezepte aus der Sammlung bringen sie fertig mit (tools/rezepte/naehrwerte.py).
//  - Eigene Rezepte rechnet die App selbst – mit derselben Tabelle
//    (apps/rezepte/data/naehrwerte.json) und denselben Regeln wie das Skript.
// ============================================================

struct Nutrition: Codable, Hashable {
    var kcal: Double
    var p: Double       // Eiweiß
    var kh: Double      // Kohlenhydrate
    var z: Double       // davon Zucker
    var f: Double       // Fett
    var bs: Double      // Ballaststoffe

    /// Anteile an der Energie (Eiweiß, Kohlenhydrate, Fett) – für den Balken
    var shares: (p: Double, kh: Double, f: Double) {
        let e = p * 4 + kh * 4 + f * 9
        guard e > 0 else { return (0, 0, 0) }
        return (p * 4 / e, kh * 4 / e, f * 9 / e)
    }
}

final class NutritionCalc: ObservableObject {
    static let shared = NutritionCalc()

    struct Food: Codable {
        let k: [String]
        let v: [Double]
        let w: [String: Double]?
        let c: String?
        let d: Double?
        func weight(_ field: String) -> Double? { w?[field] }
    }
    private struct Table: Codable { let foods: [Food] }

    @Published private(set) var ready = false
    private var foods: [Food] = []
    private var found: [String: Int] = [:]          // Name → Index in foods (-1 = kein Treffer)

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("naehrwerte.json")
    }

    /// Tabelle laden – zuerst aus dem Zwischenspeicher, dann frisch aus dem Repo
    func load() async {
        if foods.isEmpty, let d = try? Data(contentsOf: cacheURL), let t = try? JSONDecoder().decode(Table.self, from: d) {
            use(t)
        }
        guard let (data, resp) = try? await URLSession.shared.data(from: KitchenStore.recipeBase.appendingPathComponent("naehrwerte.json")),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let t = try? JSONDecoder().decode(Table.self, from: data) else { return }
        use(t)
        try? data.write(to: cacheURL)
    }

    private func use(_ t: Table) {
        foods = t.foods
        found = [:]
        ready = !foods.isEmpty
    }

    /// Nährwerte eines Rezepts: aus der Sammlung, bei eigenen Rezepten berechnet
    func nutrition(_ r: Recipe) -> Nutrition? {
        if !r.isOwn, let n = r.nutri { return n }
        return compute(r)
    }

    // MARK: Zutat → Lebensmittel

    private static let plural: Set<String> = ["", "e", "n", "en", "s", "er", "es"]

    private func norm(_ name: String) -> String {
        var n = name.lowercased()
        while let r = n.range(of: #"\([^)]*\)"#, options: .regularExpression) { n.replaceSubrange(r, with: " ") }
        n = String(n.split(separator: ",", omittingEmptySubsequences: false).first ?? "")
        let alts = n.replacingOccurrences(of: #"\s+oder\s+|\s+und\s+|\s*\+\s*"#, with: "|", options: .regularExpression)
            .split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // „Lamm- oder Rinderhack“: der erste Teil ist nur ein Wortanfang → den letzten nehmen
        if let first = alts.first, let last = alts.last { n = first.hasSuffix("-") ? last : first }
        n = n.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return " " + n + " "
    }

    /// Ganzes Wort („=ei“) oder Wortanfang bzw. Ende eines zusammengesetzten Worts („kirschtomaten“)
    private func hit(_ text: String, _ key: String) -> Bool {
        let whole = key.hasPrefix("=")
        let k = whole ? String(key.dropFirst()) : key
        guard !k.isEmpty else { return false }
        var from = text.startIndex
        while from < text.endIndex, let r = text.range(of: k, options: .literal, range: from..<text.endIndex) {
            let before: Character = r.lowerBound == text.startIndex ? " " : text[text.index(before: r.lowerBound)]
            var rest = ""
            var i = r.upperBound
            while i < text.endIndex, text[i].isLetter { rest.append(text[i]); i = text.index(after: i) }
            if whole {
                if before == " " && Self.plural.contains(rest) { return true }
            } else if before == " " || before == "-" || Self.plural.contains(rest) {
                return true
            }
            from = text.index(after: r.lowerBound)
        }
        return false
    }

    private func find(_ name: String) -> Food? {
        if let i = found[name] { return i >= 0 ? foods[i] : nil }
        let t = norm(name)
        var best = -1, len = 0
        for (i, f) in foods.enumerated() {
            for k in f.k {
                let l = k.hasPrefix("=") ? k.count - 1 : k.count
                if l > len && hit(t, k) { best = i; len = l }
            }
        }
        found[name] = best
        return best >= 0 ? foods[best] : nil
    }

    // MARK: Menge → Gramm

    private static let fractions: [String: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3]
    private static let numberPattern = try! NSRegularExpression(
        pattern: #"^(?:ca\.\s*)?(\d+(?:[.,]\d+)?)?\s*([½¼¾⅓⅔])?(?:\s*[–-]\s*(\d+(?:[.,]\d+)?))?\s*(.*)$"#)

    /// "1½ EL" → (1.5, "EL"); "1–2" → (1.5, ""); ohne Zahl → nil
    private func number(_ s: String) -> (value: Double, rest: String)? {
        let text = s.trimmingCharacters(in: .whitespaces)
        let ns = text as NSString
        guard let m = Self.numberPattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func g(_ i: Int) -> String? { let r = m.range(at: i); return r.location == NSNotFound ? nil : ns.substring(with: r) }
        let whole = g(1), frac = g(2)
        guard whole != nil || frac != nil else { return nil }
        var n = whole.flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) } ?? 0
        n += frac.flatMap { Self.fractions[$0] } ?? 0
        if let b = g(3), let v = Double(b.replacingOccurrences(of: ",", with: ".")) { n = (n + v) / 2 }
        return (n, (g(4) ?? "").trimmingCharacters(in: .whitespaces))
    }

    private static let units: [(String, String?, Double)] = [
        (#"^kg\b"#, nil, 1000), (#"^g\b"#, nil, 1), (#"^l\b"#, "ml", 1000), (#"^ml\b"#, "ml", 1), (#"^cl\b"#, "ml", 10),
        (#"^el\b"#, "el", 12), (#"^tl\b"#, "tl", 4), ("^prise", nil, 0.4), ("^msp", nil, 0.5),
        ("^handvoll", "hand", 30), ("^bund", "bund", 25), ("^scheibe", "scheibe", 25), ("^dose", "dose", 400),
        ("^glas", "dose", 300), ("^(pck|päckchen|packung|beutel)", "pck", 10), ("^würfel", "wuerfel", 10),
        ("^zweig", nil, 1.5), ("^stängel", nil, 15), ("^stange", "stange", 60), ("^spritzer", nil, 3),
        ("^rolle", "pck", 275), ("^kugel", "st", 125), ("^(blatt|blätter)", "blatt", 2), ("^streifen", nil, 5),
        ("^paar", nil, 100), ("^(stück|stk)", "st", 100), ("^kopf", "st", 500), ("^knolle", nil, 50),
        ("^(zehe|zehen)", nil, 4), ("^tasse", nil, 150), ("^becher", "pck", 200),
    ]

    private func has(_ s: String, _ pattern: String) -> Bool { s.range(of: pattern, options: .regularExpression) != nil }

    private func firstGroup(_ s: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
    }

    private func grams(_ amount: String, _ food: Food?) -> Double? {
        guard let num = number(amount) else { return nil }
        let n = num.value
        let r = num.rest.lowercased()
        // „1 Dose (400 g)“, „2 Dosen (je 400 g)“
        if let g = firstGroup(r, #"\((?:je\s*)?(?:ca\.\s*)?(\d+(?:[.,]\d+)?)\s*(g|ml|kg)\)"#),
           let v = Double(g[0].replacingOccurrences(of: ",", with: ".")) {
            return n * v * (g[1] == "kg" ? 1000 : 1)
        }
        // „1 Stück (3 cm)“ Ingwer
        if let g = firstGroup(r, #"\((\d+)\s*cm\)"#), let cm = Double(g[0]) { return n * cm * 5 }
        if r == "portionen" || r == "portion" { return n * 90 }
        if r == "rezept" { return nil }
        for (pattern, field, fallback) in Self.units where has(r, pattern) {
            if field == "ml" { return n * fallback * (food?.d ?? 1) }
            var v = field.flatMap { food?.weight($0) }
            if field == "tl", v == nil, let el = food?.weight("el") { v = el / 3 }
            return n * (v ?? fallback)
        }
        if r.isEmpty || has(r, #"^(große?|kleine?|mittelgroße?)\b"#) {
            return food?.weight("st").map { n * $0 }
        }
        return nil
    }

    // MARK: Rezept → pro Portion

    private func compute(_ r: Recipe) -> Nutrition? {
        guard ready else { return nil }
        var tot = [Double](repeating: 0, count: 6)
        var counted = 0, withAmount = 0
        let steps = r.steps.map(\.text).joined(separator: " ").lowercased()
        let fry = #"frittier|ausbacken|ausgebacken|schwimmend|zum backen in"#
        for ing in r.ingredients where !ing.name.isEmpty {
            var name = ing.name
            var amount = (ing.amount ?? "").trimmingCharacters(in: .whitespaces)
            let low = name.lowercased().trimmingCharacters(in: .whitespaces)
            let num = amount.isEmpty ? nil : number(amount)
            var g: Double?
            // „8 | Scheiben Baguette“ → Menge „8 Scheiben“
            if let num = num, num.rest.isEmpty,
               let m = firstGroup(low, #"^(bund|scheiben?|zweige?|stängel|blätter|blatt|kopf|stangen?|dosen?|handvoll|packungen?|päckchen)\s+(.*)$"#) {
                amount += " " + m[0]; name = m[1]
            }
            // „2 | Kalbsschnitzel (je 150 g)“
            if let num = num, let m = firstGroup(low, #"\(je\s*(?:ca\.\s*)?(\d+)\s*(g|kg)"#), let v = Double(m[0]) {
                g = num.value * v * (m[1] == "kg" ? 1000 : 1)
            }
            var food = find(name)
            // „2 TL Paprika“ ist Paprikapulver, nicht die Schote
            if let f = food, f.k.contains("=paprika"), has(amount.lowercased(), #"^\s*[\d½¼¾,.–-]*\s*(tl|el|prise|msp)"#) {
                food = find("paprikapulver")
            }
            if !amount.isEmpty { withAmount += 1 }
            let hint = low
            if g == nil { g = grams(amount, food) }
            guard let f = food else { continue }
            guard var qty = g else {
                if has(hint, #"zum (an)?braten|zum einfetten|für die (form|pfanne)"#) {
                    for i in 0..<min(6, f.v.count) { tot[i] += f.v[i] * 8 / 100 }
                }
                continue
            }
            if has(hint, fry) || has((ing.group ?? "").lowercased(), fry) {
                qty *= 0.06                              // Frittieröl: nur was ans Essen geht
            } else if f.v.count > 4, f.v[4] >= 80, qty >= 100, has(steps, fry) {
                qty *= 0.25                              // schwimmend ausbacken
            }
            for i in 0..<min(6, f.v.count) { tot[i] += f.v[i] * qty / 100 }
            counted += 1
        }
        // Zu wenig erkannt → lieber nichts zeigen als eine falsche Zahl
        guard counted > 0, Double(counted) >= Double(withAmount) * 0.6, tot[0] > 0 else { return nil }
        let s = Double(r.baseServings)
        return Nutrition(kcal: (tot[0] / s / 10).rounded() * 10, p: (tot[1] / s).rounded(), kh: (tot[2] / s).rounded(),
                         z: (tot[3] / s).rounded(), f: (tot[4] / s).rounded(), bs: (tot[5] / s).rounded())
    }
}
