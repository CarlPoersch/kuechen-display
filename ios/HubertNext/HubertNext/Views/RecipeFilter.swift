import SwiftUI

// ============================================================
// Rezept-Filter: Kategorie (Leiste oben), dazu im Filter-Blatt
// Sammlung, Ernährung, Zeit, Aufwand, Vorrat und Zutaten.
// ============================================================

struct RecipeFilter: Equatable {
    var collection = "Alle"          // Alle, Eigene, Airfryer, Favoriten, Lange nicht
    var diet = "Alle"                // Alle, Vegetarisch, Vegan, Ohne Fleisch
    var glutenFree = false
    var maxMinutes = 0               // 0 = egal
    var level = "Alle"               // Alle, einfach, mittel, anspruchsvoll
    var pantry = false               // mit meinem Vorrat kochen
    var maxMissing = 2
    var include: [String] = []       // muss diese Zutaten enthalten

    static let collections = ["Alle", "Eigene", "Airfryer", "Favoriten", "Lange nicht"]
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
    static let times = [0, 20, 30, 60]
    static let levels = ["Alle", "einfach", "mittel", "anspruchsvoll"]

    static let categories: [(String, String)] = [
        ("Alle", "🍽️"), ("Hauptgericht", "🍲"), ("Suppe", "🥣"), ("Salat", "🥗"), ("Beilage", "🍟"),
        ("Snack", "🥨"), ("Frühstück", "🥐"), ("Dessert", "🍰"), ("Backen", "🥖"), ("Getränk", "🥤"),
    ]

    /// Aktive Filter als kurze Texte – für die Kapseln unter der Suche
    var chips: [(label: String, clear: (inout RecipeFilter) -> Void)] {
        var out: [(label: String, clear: (inout RecipeFilter) -> Void)] = []
        if collection != "Alle" { out.append((collection, { $0.collection = "Alle" })) }
        if diet != "Alle" { out.append((diet, { $0.diet = "Alle" })) }
        if glutenFree { out.append(("Glutenfrei", { $0.glutenFree = false })) }
        if maxMinutes > 0 { out.append(("bis \(maxMinutes) Min.", { $0.maxMinutes = 0 })) }
        if level != "Alle" { out.append((level.capitalized, { $0.level = "Alle" })) }
        if pantry { out.append((maxMissing == 0 ? "Alles im Vorrat" : "Vorrat, fehlt ≤ \(maxMissing)", { $0.pantry = false })) }
        for z in include { out.append(("mit \(z)", { f in f.include.removeAll { $0 == z } })) }
        return out
    }

    var isActive: Bool { self != RecipeFilter() }
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

    var body: some View {
        NavigationView {
            Form {
                Section("Sammlung") {
                    Picker("Zeigen", selection: $filter.collection) {
                        ForEach(RecipeFilter.collections, id: \.self) { Text($0) }
                    }
                }

                Section {
                    Picker("Ernährung", selection: $filter.diet) {
                        ForEach(RecipeFilter.diets, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Glutenfrei", isOn: $filter.glutenFree)
                } header: { Text("Ernährung") } footer: {
                    Text((DietPreference.kitchen == "Alle" ? "" : "Voreingestellt: \(DietPreference.kitchen) – dauerhaft änderbar in den Einstellungen der Küche. ")
                         + "Erkannt an den Zutaten. Bei Unverträglichkeiten bitte die Verpackungen prüfen.")
                }

                Section("Zeit") {
                    Picker("Zeit", selection: $filter.maxMinutes) {
                        ForEach(RecipeFilter.times, id: \.self) { Text($0 == 0 ? "Egal" : "≤ \($0) Min.") }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Aufwand") {
                    Picker("Aufwand", selection: $filter.level) {
                        ForEach(RecipeFilter.levels, id: \.self) { Text($0 == "Alle" ? "Egal" : $0.capitalized) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Mit meinem Vorrat kochen", isOn: $filter.pantry.animation())
                    if filter.pantry {
                        Stepper(filter.maxMissing == 0 ? "Alles muss da sein" : "Fehlt höchstens \(filter.maxMissing) \(filter.maxMissing == 1 ? "Zutat" : "Zutaten")",
                                value: $filter.maxMissing, in: 0...5)
                    }
                } header: { Text("Vorrat") } footer: {
                    Text(kitchen.pantry.isEmpty
                         ? "Dein Vorrat ist noch leer – trag ihn im Tab „Vorrat“ ein oder scanne einen Kassenzettel."
                         : "Sortiert nach fehlenden Zutaten. Salz, Pfeffer, Öl, Zucker und Wasser zählen als vorhanden.")
                }

                Section {
                    ForEach(filter.include, id: \.self) { z in
                        HStack {
                            Text(z)
                            Spacer()
                            RemoveButton(name: z) { filter.include.removeAll { $0 == z } }
                        }
                    }
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent)
                        TextField("Zutat, z. B. Kartoffeln", text: $newIngredient)
                            .submitLabel(.done)
                            .onSubmit { addIngredient(newIngredient) }
                    }
                    let suggestions = kitchen.pantry.map(\.name).filter { !filter.include.contains($0) }.prefix(12)
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(suggestions), id: \.self) { n in
                                    Button { addIngredient(n) } label: {
                                        Text(n).font(.subheadline)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: { Text("Mit diesen Zutaten") } footer: {
                    Text("Zeigt nur Rezepte, die alle genannten Zutaten enthalten. Vorschläge kommen aus deinem Vorrat.")
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

    private func addIngredient(_ raw: String) {
        let z = raw.trimmingCharacters(in: .whitespaces)
        guard !z.isEmpty, !filter.include.contains(where: { $0.lowercased() == z.lowercased() }) else { newIngredient = ""; return }
        withAnimation { filter.include.append(z) }
        newIngredient = ""
    }
}
