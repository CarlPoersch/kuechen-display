import SwiftUI

// ============================================================
// Rezept-Filter: alles Einschränkende an einem Ort (Filter-Blatt).
// Auf der Rezeptseite erscheinen nur die aktiven Filter als Kapseln.
// ============================================================

struct RecipeFilter: Equatable {
    var collection = "Alle"          // Alle, Eigene, Favoriten, Lange nicht
    var cats: Set<String> = []       // Gericht – leer = alle
    var cuisine = "Alle"             // Land/Küche
    var diet = "Alle"                // Alle, Vegetarisch, Vegan, Ohne Fleisch
    var glutenFree = false
    var maxMinutes = 0               // 0 = egal
    var level = "Alle"               // Alle, einfach, mittel, anspruchsvoll
    var airfryer = false             // nur Airfryer-Rezepte
    var pantry = false               // mit meinem Vorrat kochen
    var maxMissing = 2
    var include: [String] = []       // muss diese Zutaten enthalten

    static let collections = ["Alle", "Eigene", "Favoriten", "Lange nicht"]
    static func collectionLabel(_ c: String) -> String {
        switch c {
        case "Alle": return "Alle Rezepte"
        case "Eigene": return "Nur eigene"
        case "Favoriten": return "Nur Favoriten"
        default: return "Lange nicht gekocht"
        }
    }
    static let diets = ["Alle", "Vegetarisch", "Vegan", "Ohne Fleisch"]

    /// Passt das Rezept zur Ernährung? (erkannt an den Zutaten, wenn nicht angegeben)
    static func fits(_ r: RecipeSummary, diet: String) -> Bool {
        let d = r.diet ?? DietGuess.diet(r.ing ?? [])
        switch diet {
        case "Vegetarisch": return d == "vegetarisch" || d == "vegan"
        case "Vegan": return d == "vegan"
        case "Ohne Fleisch": return d != "fleisch"
        default: return true
        }
    }
    static let times = [0, 20, 30, 45, 60]
    static let levels = ["Alle", "einfach", "mittel", "anspruchsvoll"]

    static let categories: [(String, String)] = [
        ("Hauptgericht", "🍲"), ("Suppe", "🥣"), ("Salat", "🥗"), ("Beilage", "🍟"),
        ("Snack", "🥨"), ("Frühstück", "🥐"), ("Dessert", "🍰"), ("Backen", "🥖"), ("Getränk", "🥤"),
    ]

    /// Aktive Filter als kurze Texte – für die Kapseln unter der Suche
    var chips: [(label: String, clear: (inout RecipeFilter) -> Void)] {
        var out: [(label: String, clear: (inout RecipeFilter) -> Void)] = []
        if collection != "Alle" { out.append((collection == "Lange nicht" ? "Lange nicht gekocht" : collection, { $0.collection = "Alle" })) }
        for c in RecipeFilter.categories.map(\.0) where cats.contains(c) { out.append((c, { $0.cats.remove(c) })) }
        if cuisine != "Alle" { out.append((RecipesTab.flag(cuisine) + " " + cuisine, { $0.cuisine = "Alle" })) }
        if diet != "Alle" { out.append((diet, { $0.diet = "Alle" })) }
        if glutenFree { out.append(("Glutenfrei", { $0.glutenFree = false })) }
        if maxMinutes > 0 { out.append(("≤ \(maxMinutes) Min.", { $0.maxMinutes = 0 })) }
        if level != "Alle" { out.append((level.capitalized, { $0.level = "Alle" })) }
        if airfryer { out.append(("Airfryer", { $0.airfryer = false })) }
        if pantry { out.append((maxMissing == 0 ? "Alles im Vorrat" : "Vorrat, fehlt ≤ \(maxMissing)", { $0.pantry = false })) }
        for z in include { out.append(("mit \(z)", { f in f.include.removeAll { $0 == z } })) }
        return out
    }

    var isActive: Bool { self != RecipeFilter() }

    /// Passende Rezepte mit fehlenden Zutaten (nur bei „Mit meinem Vorrat“ gefüllt) – für Liste, Filter und Würfel
    func apply(_ recipes: [RecipeSummary], query: String = "", kitchen: KitchenStore = .shared) -> [(RecipeSummary, [String])] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        let pantryKeys = pantry ? kitchen.pantry.map { FoodCatalog.key($0.name) } : []
        var out: [(RecipeSummary, [String])] = []
        for r in recipes {
            if !q.isEmpty {
                let ing = (r.ing ?? []).map { $0.lowercased() }
                if !(r.title.lowercased().contains(q) || (r.cuisine ?? "").lowercased().contains(q) || ing.contains(where: { $0.contains(q) })) { continue }
            }
            if !cats.isEmpty && !cats.contains(r.cat ?? "Hauptgericht") { continue }
            if cuisine != "Alle" && (r.cuisine ?? "Sonstige") != cuisine { continue }
            let m = kitchen.meta[r.id]
            switch collection {
            case "Eigene": if r.owner == nil { continue }
            case "Favoriten": if m?.favorite != true { continue }
            case "Lange nicht": if let d = m?.lastCookedDate, Date().timeIntervalSince(d) <= 21 * 86400 { continue }
            default: break
            }
            if airfryer && r.airfryer != true { continue }
            if !RecipeFilter.fits(r, diet: diet) { continue }
            if glutenFree && r.gf != true { continue }
            if maxMinutes > 0 && (r.minutes ?? 999) > maxMinutes { continue }
            if level != "Alle" && r.level != level { continue }
            // Zutaten: mit Oberbegriffen, Varianten und anderen Namen (IngredientSearch)
            if !include.allSatisfy({ IngredientSearch.has(r, $0) }) { continue }
            var missing: [String] = []
            if pantry {
                missing = PantryMatch.missing(r, pantry: pantryKeys)
                if missing.count > maxMissing { continue }
            }
            out.append((r, missing))
        }
        if pantry { out.sort { $0.1.count < $1.1.count } }
        else if collection == "Favoriten" {
            // Lange nicht (oder nie) Gekochtes zuerst, damit nicht immer dieselben oben stehen
            out.sort { (kitchen.meta[$0.0.id]?.lastCookedDate ?? .distantPast) < (kitchen.meta[$1.0.id]?.lastCookedDate ?? .distantPast) }
        }
        return out
    }
}

/// Wie viele Zutaten fehlen? Grundzutaten zählen als vorhanden.
enum PantryMatch {
    static func isStaple(_ key: String) -> Bool {
        key.hasPrefix("salz") || key.contains("pfeffer") && !key.contains("schote") || key.contains("wasser")
            || key.hasSuffix("öl") || key == "zucker" || key.hasPrefix("öl")
    }

    static func missing(_ r: RecipeSummary, pantry: [FoodKey]) -> [String] {
        (r.ing ?? []).filter { name in
            let k = KitchenStore.key(name)
            guard !k.isEmpty, !isStaple(k) else { return false }
            let i = FoodCatalog.key(name)
            return !pantry.contains { FoodCatalog.matches($0, i) }
        }
    }
}

/// Einfache Einordnung für eigene Rezepte (die Sammlung bringt sie fertig mit)
enum DietGuess {
    private static let meat = ["hähnchen", "huhn", "hühner", "rind", "schwein", "hackfleisch", "speck", "schinken", "wurst", "würst",
                               "lamm", "kalb", "ente", "pute", "chorizo", "salami", "bacon", "fleisch", "gulasch", "pancetta"]
    private static let fish = ["lachs", "thunfisch", "garnele", "fisch", "kabeljau", "forelle", "sardelle", "muschel", "shrimp",
                               "krabbe", "austernsauce", "dashi", "hering", "seelachs"]
    private static let animal = ["eier", "eigelb", "milch", "butter", "sahne", "käse", "parmesan", "mozzarella", "feta", "joghurt",
                                 "quark", "honig", "schmand", "crème", "ricotta", "mascarpone", "ghee", "paneer", "halloumi"]
    private static let veganOK = ["kokosmilch", "hafermilch", "mandelmilch", "sojamilch", "erdnussbutter", "vegan"]

    static func diet(_ names: [String]) -> String {
        let t = names.map { $0.lowercased() }.joined(separator: " | ")
        let clean = veganOK.reduce(t) { $0.replacingOccurrences(of: $1, with: "") }
        if meat.contains(where: { clean.contains($0) }) && !clean.contains("fleischtomate") { return "fleisch" }
        if fish.contains(where: { clean.contains($0) }) { return "fisch" }
        let words = clean.components(separatedBy: CharacterSet.letters.inverted)
        if animal.contains(where: { clean.contains($0) }) || words.contains("ei") { return "vegetarisch" }
        return "vegan"
    }
}

/// Filter-Blatt
struct RecipeFilterSheet: View {
    @Binding var filter: RecipeFilter
    let count: (RecipeFilter) -> Int
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var newIngredient = ""
    @FocusState private var typing: Bool

    var body: some View {
        NavigationView {
            Form {
                // Zutaten zuerst: wird getippt, bleiben Feld und Vorschläge über der Tastatur sichtbar
                ingredientSection

                Section("Angezeigte Rezepte") {
                    Picker("Rezepte", selection: $filter.collection) {
                        ForEach(RecipeFilter.collections, id: \.self) { Text(RecipeFilter.collectionLabel($0)).tag($0) }
                    }
                }

                Section {
                    ChipGrid(items: RecipeFilter.categories.map { ($0.0, $0.1) }, selected: $filter.cats)
                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                } header: {
                    HStack {
                        Text("Gericht")
                        Spacer()
                        if !filter.cats.isEmpty {
                            Button("Alle") { withAnimation { filter.cats = [] } }.font(.footnote).textCase(nil)
                        }
                    }
                } footer: { Text("Nichts gewählt = alle Gerichte. Mehrere gehen auch, z. B. Hauptgericht und Suppe.") }

                Section("Land") {
                    NavigationLink(destination: CuisinePickerList(selection: $filter.cuisine)) {
                        HStack {
                            Text("Küche")
                            Spacer()
                            Text(filter.cuisine == "Alle" ? "Alle Länder" : RecipesTab.flag(filter.cuisine) + " " + filter.cuisine)
                                .foregroundColor(Theme.secondary).lineLimit(1)
                        }
                    }
                }

                Section {
                    Picker("Ernährung", selection: $filter.diet) {
                        ForEach(RecipeFilter.diets, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Glutenfrei", isOn: $filter.glutenFree).tint(Theme.accent)
                } header: { Text("Ernährung") } footer: {
                    Text((DietPreference.kitchen == "Alle" ? "" : "Voreingestellt: \(DietPreference.kitchen) – dauerhaft änderbar in den Einstellungen der Küche. ")
                         + "Erkannt an den Zutaten. Bei Unverträglichkeiten bitte die Verpackungen prüfen.")
                }

                Section("Zeit und Aufwand") {
                    Picker("Zeit", selection: $filter.maxMinutes) {
                        ForEach(RecipeFilter.times, id: \.self) { Text($0 == 0 ? "Egal" : "höchstens \($0) Min.").tag($0) }
                    }
                    Picker("Aufwand", selection: $filter.level) {
                        ForEach(RecipeFilter.levels, id: \.self) { Text($0 == "Alle" ? "Egal" : $0.capitalized).tag($0) }
                    }
                }

                Section {
                    Toggle(isOn: $filter.airfryer.animation()) {
                        HStack { Text("Nur Airfryer"); Spacer(); Text("\(airfryerCount)").foregroundColor(Theme.secondary).monospacedDigit() }
                    }
                    .tint(Theme.accent)
                    Toggle(isOn: $filter.pantry.animation()) {
                        HStack { Text("Mit meinem Vorrat"); Spacer(); Text(kitchen.pantry.isEmpty ? "leer" : "\(pantryCount)").foregroundColor(Theme.secondary).monospacedDigit() }
                    }
                    .tint(Theme.accent)
                    if filter.pantry {
                        Stepper(filter.maxMissing == 0 ? "Alles muss da sein" : "Fehlt höchstens \(filter.maxMissing) \(filter.maxMissing == 1 ? "Zutat" : "Zutaten")",
                                value: $filter.maxMissing, in: 0...5)
                    }
                } header: { Text("Zubereitung und Vorrat") } footer: {
                    Text(kitchen.pantry.isEmpty
                         ? "Dein Vorrat ist noch leer – trag ihn im Tab „Vorrat“ ein oder scanne einen Kassenzettel."
                         : "Mit Vorrat: sortiert nach fehlenden Zutaten. Salz, Pfeffer, Öl, Zucker und Wasser zählen als vorhanden.")
                }
            }
            .navigationTitle("Filter").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zurücksetzen") { withAnimation { filter = RecipeFilter() } }.disabled(!filter.isActive)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                let n = count(filter)
                Button { dismiss() } label: {
                    Text(n == 1 ? "1 Rezept anzeigen" : "\(n) Rezepte anzeigen")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(n == 0 ? Color.gray : Theme.accent))
                }
                .buttonStyle(.plain)
                .padding(.horizontal).padding(.vertical, 8)
                .background(.regularMaterial)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var ingredientQuery: String { newIngredient.trimmingCharacters(in: .whitespaces) }

    /// Wie viele Rezepte mit dem Schalter dazu passen würden (übrige Filter bleiben)
    private var airfryerCount: Int { var f = filter; f.airfryer = true; return count(f) }
    private var pantryCount: Int { var f = filter; f.pantry = true; return count(f) }

    /// Vorschläge zur Eingabe – nur solche, die mit den übrigen Filtern noch Rezepte ergeben
    private var suggestions: [IngredientSearch.Suggestion] {
        IngredientSearch.suggest(ingredientQuery, chosen: filter.include, recipes: kitchen.recipes) { name in
            var f = filter
            f.include.append(name)
            return count(f)
        }
    }

    @ViewBuilder private var ingredientSection: some View {
        let sugg = suggestions
        Section {
            // Gewählte Zutaten als Chips – antippen entfernt
            if !filter.include.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filter.include, id: \.self) { z in
                            Button { withAnimation { filter.include.removeAll { $0 == z } } } label: {
                                HStack(spacing: 6) {
                                    Text(z).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Image(systemName: "xmark").font(.caption2.weight(.bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).frame(minHeight: 34)
                                .background(Capsule().fill(Theme.accent))
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(z) entfernen")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
                TextField(filter.include.isEmpty ? "Zutat, z. B. Kartoffeln" : "Weitere Zutat …", text: $newIngredient)
                    .focused($typing)
                    .submitLabel(.done)
                    .disableAutocorrection(true)
                    .onSubmit { addIngredient(sugg.first?.name ?? newIngredient) }
                if !newIngredient.isEmpty {
                    Button { newIngredient = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Eingabe löschen")
                }
            }
            .frame(minHeight: 44)
            // Vorschläge beim Tippen: antippen fügt hinzu, das Feld bleibt für die nächste Zutat offen
            ForEach(sugg) { s in
                Button { addIngredient(s.name) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle").font(.title3).foregroundColor(Theme.accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            ShopSuggest.highlighted(s.name, ingredientQuery).foregroundColor(.primary).lineLimit(1)
                            if !s.hint.isEmpty { Text(s.hint).font(.caption).foregroundColor(Theme.secondary) }
                        }
                        Spacer(minLength: 8)
                        Text(s.count == 1 ? "1 Rezept" : "\(s.count) Rezepte")
                            .font(.caption.monospacedDigit()).foregroundColor(Theme.secondary).lineLimit(1)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(s.name) hinzufügen, \(s.count) Rezepte")
            }
            if !ingredientQuery.isEmpty && sugg.isEmpty {
                Text(filter.include.isEmpty ? "Kein Rezept mit „\(ingredientQuery)“."
                                            : "Kein Rezept mit „\(ingredientQuery)“ und den gewählten Zutaten.")
                    .font(.subheadline).foregroundColor(Theme.secondary)
            }
            // Feld leer: Vorschläge aus dem Vorrat (nur solche, die Rezepte ergeben)
            if ingredientQuery.isEmpty {
                let fromPantry = kitchen.pantry.map(\.name)
                    .filter { n in !filter.include.contains(where: { $0.lowercased() == n.lowercased() }) }
                    .prefix(16)
                    .filter { n in var f = filter; f.include.append(n); return count(f) > 0 }
                    .prefix(10)
                if !fromPantry.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(fromPantry), id: \.self) { n in
                                Button { addIngredient(n) } label: {
                                    Text(n).font(.subheadline)
                                        .padding(.horizontal, 12).frame(minHeight: 34)
                                        .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        } header: { Text("Mit diesen Zutaten") } footer: {
            Text("Zeigt Rezepte mit allen gewählten Zutaten. „Nudeln“ findet auch Spaghetti, „Tomaten“ auch Cherrytomaten, „Sahne“ auch Rahm.")
        }
    }

    private func addIngredient(_ raw: String) {
        let z = raw.trimmingCharacters(in: .whitespaces)
        guard !z.isEmpty, !filter.include.contains(where: { $0.lowercased() == z.lowercased() }) else {
            newIngredient = ""; typing = true; return
        }
        withAnimation { filter.include.append(z) }
        newIngredient = ""
        typing = true          // Tastatur bleibt offen für die nächste Zutat
    }
}

/// Chips zum An- und Abwählen (mehrfach), umbrechend – auf jedem Gerät ohne Abschneiden
struct ChipGrid: View {
    let items: [(String, String)]            // (Name, Emoji)
    @Binding var selected: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.0) { item in
                let on = selected.contains(item.0)
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { if on { selected.remove(item.0) } else { selected.insert(item.0) } }
                } label: {
                    HStack(spacing: 6) {
                        Text(item.1)
                        Text(item.0).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                        if on { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                    }
                    .foregroundColor(on ? Theme.accent : .primary)
                    .padding(.horizontal, 12).frame(minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(on ? Theme.accent.opacity(0.14) : Color(UIColor.tertiarySystemFill)))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.0 + (on ? ", ausgewählt" : ""))
            }
        }
    }
}

/// Länder-Auswahl mit Flagge und Anzahl (die häufigsten zuerst)
struct CuisinePickerList: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var search = ""

    private var cuisines: [(String, Int)] {
        Dictionary(grouping: kitchen.recipes) { $0.cuisine ?? "Sonstige" }
            .map { ($0.key, $0.value.count) }
            .filter { search.isEmpty || $0.0.lowercased().contains(search.lowercased()) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
    }

    var body: some View {
        List {
            if search.isEmpty { row("Alle", "🌍", "Alle Länder", kitchen.recipes.count) }
            ForEach(cuisines, id: \.0) { c in row(c.0, RecipesTab.flag(c.0), c.0, c.1) }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Land suchen")
        .navigationTitle("Land").navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ value: String, _ flag: String, _ label: String, _ n: Int) -> some View {
        Button { selection = value; dismiss() } label: {
            HStack(spacing: 12) {
                Text(flag).font(.title3)
                Text(label).foregroundColor(.primary)
                Spacer()
                Text("\(n)").foregroundColor(Theme.secondary).monospacedDigit()
                if selection == value { Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundColor(Theme.accent) }
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
