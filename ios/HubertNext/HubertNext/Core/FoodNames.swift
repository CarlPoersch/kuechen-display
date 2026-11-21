import Foundation

// ============================================================
// Saubere Vorratsnamen ohne KI: "G&G AVOCADOS" → "Avocados",
// "BIO VOLLM. 3,8%" → "Vollmilch".
//  1. Marken, Mengen, Prozente, Pfand entfernen
//  2. typische Kassen-Abkürzungen auflösen
//  3. mit einer Lebensmittelliste abgleichen (Grundliste + Zutaten der Rezepte)
// Was der Haushalt korrigiert, lernt KitchenStore (kitchen_aliases) und
// hat immer Vorrang vor dieser Regel-Bereinigung.
// ============================================================

enum FoodNames {

    /// Schlüssel für gelernte Zuordnungen: nur Buchstaben/Ziffern, groß, ohne Mengen
    static func key(_ raw: String) -> String {
        var s = raw.uppercased()
        s = s.replacingOccurrences(of: #"\d+([,.]\d+)?\s*(KG|G|ML|L|CL|ST|STK|ER|%|X)?\b"#, with: " ", options: .regularExpression)
        s = s.components(separatedBy: CharacterSet.letters.union(CharacterSet(charactersIn: "&")).inverted).filter { !$0.isEmpty }.joined(separator: " ")
        return s
    }

    /// Handelsmarken und Zusätze, die nicht zum Lebensmittel gehören (Großschreibung, ohne Punkt)
    private static let brands: [String] = [
        "GUT & GÜNSTIG", "GUT&GÜNSTIG", "GUT & GUENSTIG", "GUT&GUENSTIG", "G&G", "G & G", "JA!", "JA",
        "K-CLASSIC", "K CLASSIC", "KCLASSIC", "K-BIO", "K BIO", "REWE BESTE WAHL", "BESTE WAHL", "REWE BIO", "REWE",
        "EDEKA BIO", "EDEKA", "E.BIO", "NETTO", "PENNY", "LIDL", "ALDI", "KAUFLAND", "NORMA", "GLOBUS", "DM BIO", "DMBIO",
        "MILBONA", "PILOS", "MILSANI", "GUT BIO", "BIOTREND", "NATURGUT", "NATURE'S PROMISE", "SAN FABIO", "COMBINO",
        "CUCINA", "BELBAKE", "GOLDEN SEAFOOD", "MEINE METZGEREI", "FREEWAY", "BAREFOOT", "CHEF SELECT", "DELUXE",
        "BIO", "BIOLAND", "DEMETER", "NATURLAND", "FAIRTRADE", "REGIONAL", "AUS DER REGION", "UNSERE HEIMAT",
        "XXL", "MAXI", "MINI", "PACK", "PCK", "PACKUNG", "BEUTEL", "BTL", "DOSE", "GLAS", "FL", "FLASCHE",
        "STK", "STÜCK", "KL", "GR", "LOSE", "TK", "TIEFGEKÜHLT", "FRISCH", "FR", "NATUR", "NAT", "KLASSIK",
        "PFAND", "EINWEG", "MEHRWEG", "ANGEBOT", "AKTION", "RABATT",
    ]

    /// Kassen-Abkürzungen (ohne Punkt, groß) → Lebensmittel
    private static let abbreviations: [String: String] = [
        "VOLLM": "Vollmilch", "VOLLMILCH": "Vollmilch", "H-MILCH": "H-Milch", "HMILCH": "H-Milch", "FETTARME MILCH": "Milch",
        "JOGH": "Joghurt", "JOGHU": "Joghurt", "SCHLAGS": "Schlagsahne", "SCHL SAHNE": "Schlagsahne", "SAHNE": "Sahne",
        "SCHM": "Schmand", "CR FRAICHE": "Crème fraîche", "CREME FR": "Crème fraîche", "FRISCHK": "Frischkäse",
        "MOZZ": "Mozzarella", "MOZZAR": "Mozzarella", "PARM": "Parmesan", "EMMENT": "Emmentaler", "GOUDA": "Gouda",
        "KAESE": "Käse", "KÄSE": "Käse", "REIBEK": "Reibekäse", "BUTT": "Butter", "MARG": "Margarine",
        "HAEHN": "Hähnchen", "HÄHN": "Hähnchen", "HAEHNCHENBR": "Hähnchenbrust", "HÄHNCHENBR": "Hähnchenbrust",
        "HÄHNCHENBRUSTF": "Hähnchenbrust", "H BRUSTF": "Hähnchenbrust", "HACKFL": "Hackfleisch", "HACK": "Hackfleisch",
        "GEM HACK": "Hackfleisch", "SCHW": "Schwein", "RINDERH": "Rinderhack", "PUTENBR": "Putenbrust",
        "KART": "Kartoffeln", "KARTOF": "Kartoffeln", "KARTOFF": "Kartoffeln", "SPEISEKART": "Kartoffeln",
        "ZWIEB": "Zwiebeln", "ZWIEBEL": "Zwiebeln", "KNOBL": "Knoblauch", "TOM": "Tomaten", "TOMAT": "Tomaten",
        "RISPENTOM": "Rispentomaten", "CHERRYTOM": "Cherrytomaten", "PAPR": "Paprika", "GURK": "Gurke",
        "SALATGURK": "Salatgurke", "KAROT": "Karotten", "MOEHR": "Möhren", "MÖHR": "Möhren", "ZUCCH": "Zucchini",
        "BROKK": "Brokkoli", "CHAMP": "Champignons", "CHAMPIGN": "Champignons", "AVOC": "Avocados", "BAN": "Bananen",
        "BANAN": "Bananen", "AEPF": "Äpfel", "ÄPF": "Äpfel", "APFEL": "Äpfel", "ZITR": "Zitronen", "LIM": "Limetten",
        "ORANG": "Orangen", "TRAUB": "Trauben", "ERDB": "Erdbeeren", "HEIDELB": "Heidelbeeren",
        "SPAG": "Spaghetti", "SPAGH": "Spaghetti", "NUD": "Nudeln", "PENNE": "Penne", "FUSILLI": "Fusilli",
        "BASMATI": "Basmatireis", "JASMIN": "Jasminreis", "REIS": "Reis", "MEHL": "Mehl", "ZUCK": "Zucker",
        "BROETCH": "Brötchen", "BRÖTCH": "Brötchen", "TOASTBR": "Toastbrot", "VOLLKORNBR": "Vollkornbrot",
        "EIER": "Eier", "FREILANDEIER": "Eier", "BODENH": "Eier", "BODENHALTUNG": "Eier", "FREIL": "Eier",
        "OLIVENOEL": "Olivenöl", "OLIVENÖL": "Olivenöl", "SONNENBL": "Sonnenblumenöl", "RAPSOEL": "Rapsöl", "RAPSÖL": "Rapsöl",
        "PASS TOM": "Passierte Tomaten", "PASSATA": "Passierte Tomaten", "TOMATENM": "Tomatenmark",
        "KOKOSM": "Kokosmilch", "SOJAS": "Sojasauce", "MINERALW": "Mineralwasser", "MIN WASSER": "Mineralwasser",
    ]

    /// Grundliste: was typischerweise im Vorrat landet (in schöner Schreibweise)
    static let basics: [String] = [
        "Milch", "Vollmilch", "H-Milch", "Hafermilch", "Sojamilch", "Butter", "Margarine", "Sahne", "Schlagsahne", "Saure Sahne",
        "Schmand", "Crème fraîche", "Quark", "Magerquark", "Joghurt", "Naturjoghurt", "Griechischer Joghurt", "Skyr",
        "Frischkäse", "Mozzarella", "Burrata", "Parmesan", "Pecorino", "Feta", "Halloumi", "Gouda", "Emmentaler", "Cheddar",
        "Camembert", "Brie", "Reibekäse", "Käse", "Eier",
        "Hähnchenbrust", "Hähnchenschenkel", "Hähnchen", "Putenbrust", "Hackfleisch", "Rinderhack", "Schweinehack",
        "Rindfleisch", "Schweinefleisch", "Schnitzel", "Bratwurst", "Würstchen", "Wiener Würstchen", "Speck", "Schinken",
        "Salami", "Lachs", "Lachsfilet", "Thunfisch", "Garnelen", "Fischstäbchen", "Tofu",
        "Kartoffeln", "Süßkartoffeln", "Zwiebeln", "Rote Zwiebeln", "Frühlingszwiebeln", "Knoblauch", "Ingwer", "Tomaten",
        "Cherrytomaten", "Rispentomaten", "Paprika", "Gurke", "Salatgurke", "Karotten", "Möhren", "Zucchini", "Aubergine",
        "Brokkoli", "Blumenkohl", "Spinat", "Blattspinat", "Rucola", "Feldsalat", "Eisbergsalat", "Kopfsalat", "Romanasalat",
        "Weißkohl", "Rotkohl", "Chinakohl", "Pak Choi", "Lauch", "Sellerie", "Fenchel", "Champignons", "Pilze", "Mais",
        "Erbsen", "Bohnen", "Grüne Bohnen", "Kürbis", "Radieschen", "Chili", "Jalapeño", "Avocados", "Petersilie",
        "Basilikum", "Koriander", "Schnittlauch", "Dill", "Minze", "Thymian", "Rosmarin",
        "Äpfel", "Bananen", "Birnen", "Orangen", "Mandarinen", "Clementinen", "Zitronen", "Limetten", "Trauben",
        "Erdbeeren", "Himbeeren", "Heidelbeeren", "Kiwi", "Mango", "Ananas", "Melone", "Pfirsiche", "Nektarinen",
        "Brot", "Toastbrot", "Vollkornbrot", "Brötchen", "Baguette", "Wraps", "Tortillas", "Fladenbrot", "Croissants",
        "Nudeln", "Spaghetti", "Penne", "Fusilli", "Tagliatelle", "Lasagneplatten", "Gnocchi", "Reisnudeln", "Ramen-Nudeln",
        "Reis", "Basmatireis", "Jasminreis", "Risottoreis", "Couscous", "Bulgur", "Quinoa", "Haferflocken", "Müsli",
        "Cornflakes", "Mehl", "Zucker", "Puderzucker", "Brauner Zucker", "Backpulver", "Hefe", "Trockenhefe", "Speisestärke",
        "Semmelbrösel", "Panko", "Linsen", "Rote Linsen", "Kichererbsen", "Kidneybohnen", "Schwarze Bohnen",
        "Passierte Tomaten", "Stückige Tomaten", "Tomatenmark", "Kokosmilch", "Brühe", "Gemüsebrühe", "Hühnerbrühe",
        "Olivenöl", "Sonnenblumenöl", "Rapsöl", "Sesamöl", "Öl", "Essig", "Balsamico", "Sojasauce", "Fischsauce",
        "Austernsauce", "Ketchup", "Mayonnaise", "Senf", "Pesto", "Currypaste", "Honig", "Marmelade", "Nutella",
        "Erdnussbutter", "Salz", "Pfeffer", "Paprikapulver", "Curry", "Zimt", "Kreuzkümmel", "Kurkuma", "Oregano",
        "Nüsse", "Mandeln", "Walnüsse", "Erdnüsse", "Cashews", "Sesam", "Rosinen", "Schokolade", "Kekse", "Chips",
        "Kaffee", "Tee", "Kakao", "Saft", "Orangensaft", "Apfelsaft", "Mineralwasser", "Wasser", "Cola", "Bier", "Wein",
        "Tiefkühlpizza", "Pizza", "Pommes", "Kroketten", "Tiefkühlgemüse", "Eis",
        "Toilettenpapier", "Küchenrolle", "Spülmittel", "Müllbeutel",
    ]

    /// Kassenzeile → sauberer Name. `extra`: weitere bekannte Lebensmittel (z. B. Zutaten der Rezepte)
    static func clean(_ raw: String, extra: [String] = []) -> String {
        var s = " " + raw.uppercased().replacingOccurrences(of: ".", with: " ") + " "
        // Mengen, Prozente, Zahlen
        s = s.replacingOccurrences(of: #"\d+([,]\d+)?\s*(KG|G|GR|ML|L|CL|ST|STK|ER|%|X)?(?=\W)"#, with: " ", options: .regularExpression)
        // Abkürzungen mit zwei Wörtern zuerst
        for (abbr, full) in abbreviations where abbr.contains(" ") {
            s = s.replacingOccurrences(of: " " + abbr + " ", with: " " + full.uppercased() + " ")
        }
        // Marken und Zusätze (längste zuerst, damit "REWE BESTE WAHL" vor "REWE" greift)
        for b in brands.sorted(by: { $0.count > $1.count }) {
            s = s.replacingOccurrences(of: " " + b + " ", with: " ")
        }
        var tokens = s.split(separator: " ").map(String.init).filter { $0.rangeOfCharacter(from: .letters) != nil }
        tokens = tokens.map { abbreviations[$0]?.uppercased() ?? $0 }
        guard !tokens.isEmpty else { return nice(raw) }

        // Mit der Lebensmittelliste abgleichen. Punkte: ganzes Wort > Wortende > Wortanfang,
        // bei Gleichstand der längere Begriff. Warum Wortende vor Wortanfang: Im Deutschen steht
        // das eigentliche Ding hinten ("EIERNUDELN" sind Nudeln, keine Eier).
        let rest = " " + tokens.joined(separator: " ").lowercased() + " "
        let words = tokens.map { $0.lowercased() }
        let foods = basics + extra
        var best: (name: String, score: Int)?
        for f in foods {
            let fl = f.lowercased()
            let st = stem(fl)
            var score = 0
            if rest.contains(" " + fl + " ") { score = 1000 + fl.count }
            else if st.count >= 4, words.contains(where: { $0.count > fl.count && ($0.hasSuffix(fl) || $0.hasSuffix(st)) }) { score = 500 + fl.count }
            else if st.count >= 4, words.contains(where: { $0.count >= 4 && ($0.hasPrefix(st) || (st.hasPrefix($0) && $0.count >= 5)) }) { score = fl.count }
            if score > (best?.score ?? 0) { best = (f, score) }
        }
        if let b = best { return b.name.prefix(1).uppercased() + b.name.dropFirst() }
        return nice(tokens.joined(separator: " "))
    }

    /// "AVOCADOS" → "Avocados"
    static func nice(_ s: String) -> String {
        s.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Grober Wortstamm ("tomaten" → "tomat", "avocados" → "avocado")
    private static func stem(_ s: String) -> String {
        for suffix in ["en", "n", "s", "e"] where s.count > 5 && s.hasSuffix(suffix) {
            return String(s.dropLast(suffix.count))
        }
        return s
    }
}
