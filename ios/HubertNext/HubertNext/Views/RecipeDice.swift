import SwiftUI

// ============================================================
// Rezept-Würfel – aufgebaut wie der Film-Würfel:
//  1. Voreinstellungen (werden gemerkt), live: wie viele Rezepte passen
//  2. Würfeln → das Rezept mit Zeit, Aufwand, Nährwerten und Zutaten
//  3. Nochmal würfeln, zurück zu den Einstellungen, Kochen oder in die Woche
// ============================================================

struct DicePrefs: Codable, Equatable {
    var cats: [String] = ["Hauptgericht"]
    var diet = "Alle"
    var maxMinutes = 0
    var level = "Alle"
    var maxKcal = 0                 // 0 = egal
    var cuisine = "Alle"
    var pantry = false
    var airfryer = false
    var favorites = false
    var notRecent = true            // nichts der letzten 14 Tage

    private static let key = "hubert.recipeDice"
    static func load() -> DicePrefs {
        guard let d = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode(DicePrefs.self, from: d) else {
            var p = DicePrefs(); p.diet = DietPreference.kitchen; return p
        }
        return p
    }
    func save() { if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) } }

    var filter: RecipeFilter {
        var f = RecipeFilter()
        f.cats = Set(cats)
        f.diet = diet
        f.maxMinutes = maxMinutes
        f.level = level
        f.cuisine = cuisine
        f.pantry = pantry
        f.maxMissing = 2
        f.airfryer = airfryer
        f.collection = favorites ? "Favoriten" : "Alle"
        return f
    }

    static let kcalSteps = [0, 400, 500, 600, 800]
}

struct RecipeDiceSheet: View {
    /// Rezept ganz öffnen (Blatt schließt sich, die Küche zeigt das Rezept) bzw. kochen
    var onOpen: (String) -> Void
    var onCook: (Recipe, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @ObservedObject private var nutrition = NutritionCalc.shared
    @State private var prefs = DicePrefs.load()
    @State private var result: RecipeSummary?
    @State private var full: Recipe?
    @State private var missing: [String] = []
    @State private var showPrefs = true
    @State private var planning = false

    private var pool: [(RecipeSummary, [String])] {
        let recent = Date().addingTimeInterval(-14 * 86400)
        return prefs.filter.apply(kitchen.recipes).filter { item in
            if prefs.maxKcal > 0, let k = item.0.kcal, k > prefs.maxKcal { return false }
            if prefs.notRecent, let d = kitchen.meta[item.0.id]?.lastCookedDate, d > recent { return false }
            return true
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let r = result, !showPrefs {
                    ScrollView { resultView(r).padding() }
                } else {
                    prefsForm
                }
                bottomBar
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Was kochen wir heute?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sheet(isPresented: $planning) {
                if let r = result { PlanSheet(recipeId: r.id, title: r.title, portions: r.servings ?? 2) }
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: prefs) { $0.save() }
    }

    // MARK: Unten: Einstellungen / Würfeln, darunter Kochen / In die Woche

    private var bottomBar: some View {
        let n = pool.count
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                if result != nil {
                    Button { withAnimation { showPrefs.toggle() } } label: {
                        Image(systemName: showPrefs ? "fork.knife" : "slider.horizontal.3").font(.body.weight(.semibold))
                            .foregroundColor(Theme.accent)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                    }
                    .accessibilityLabel(showPrefs ? "Vorschlag zeigen" : "Voreinstellungen")
                }
                Button { roll() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "die.face.5.fill")
                        Text(result == nil ? "Würfeln" : "Nochmal würfeln").font(.headline)
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(n == 0 ? Color.gray : Theme.accent))
                }
                .disabled(n == 0)
            }
            if let r = result, !showPrefs {
                HStack(spacing: 10) {
                    Button {
                        if let f = full { dismiss(); onCook(f, f.baseServings) }
                    } label: {
                        Label("Kochen", systemImage: "frying.pan").font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                    }
                    .disabled(full == nil)
                    Button { planning = true } label: {
                        Label("In die Woche", systemImage: "calendar.badge.plus").font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                    }
                    .accessibilityLabel("\(r.title) in den Wochenplan")
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.accent)
            }
        }
        .padding(16)
        .background(.regularMaterial)
    }

    // MARK: Voreinstellungen

    private var prefsForm: some View {
        Form {
            Section {
                ChipGrid(items: RecipeFilter.categories.map { ($0.0, $0.1) },
                         selected: Binding(get: { Set(prefs.cats) }, set: { s in prefs.cats = RecipeFilter.categories.map(\.0).filter { s.contains($0) } }))
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            } header: { Text("Gericht") } footer: { Text("Nichts gewählt = alle Gerichte.") }

            Section("Wünsche") {
                Picker("Ernährung", selection: $prefs.diet) {
                    ForEach(RecipeFilter.diets, id: \.self) { Text($0).tag($0) }
                }
                Picker("Höchstens", selection: $prefs.maxMinutes) {
                    ForEach(RecipeFilter.times, id: \.self) { Text($0 == 0 ? "Egal" : "\($0) Min.").tag($0) }
                }
                Picker("Aufwand", selection: $prefs.level) {
                    ForEach(RecipeFilter.levels, id: \.self) { Text($0 == "Alle" ? "Egal" : $0.capitalized).tag($0) }
                }
                Picker("Kalorien pro Portion", selection: $prefs.maxKcal) {
                    ForEach(DicePrefs.kcalSteps, id: \.self) { Text($0 == 0 ? "Egal" : "bis \($0) kcal").tag($0) }
                }
                NavigationLink(destination: CuisinePickerList(selection: $prefs.cuisine)) {
                    HStack {
                        Text("Land")
                        Spacer()
                        Text(prefs.cuisine == "Alle" ? "Alle" : RecipesTab.flag(prefs.cuisine) + " " + prefs.cuisine)
                            .foregroundColor(Theme.secondary).lineLimit(1)
                    }
                }
            }

            Section {
                Toggle("Mit meinem Vorrat", isOn: $prefs.pantry).tint(Theme.accent)
                Toggle("Nur Airfryer", isOn: $prefs.airfryer).tint(Theme.accent)
                Toggle("Nur aus Favoriten", isOn: $prefs.favorites).tint(Theme.accent)
                Toggle("Nichts der letzten 14 Tage", isOn: $prefs.notRecent).tint(Theme.accent)
            } footer: {
                let n = pool.count
                Text(n == 0 ? "Kein Rezept passt – lockere eine Einstellung."
                     : n == 1 ? "1 Rezept passt." : "\(n) Rezepte passen.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(n == 0 ? .red : Theme.secondary)
            }
        }
    }

    // MARK: Ergebnis

    @ViewBuilder
    private func resultView(_ r: RecipeSummary) -> some View {
        let n = full.flatMap { nutrition.nutrition($0) }
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Text(r.icon).font(.system(size: 44))
                    .frame(width: 68, height: 68)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.title).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text([r.cuisine.map { RecipesTab.flag($0) + " " + $0 }, dietLabel(r)].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundColor(Theme.secondary)
                }
                Spacer(minLength: 0)
                FavoriteButton(id: r.id, size: 20)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile(r.time ?? "–", "Zeit" + (r.level.map { " · " + $0 } ?? ""))
                tile(n.map { "\(Int($0.kcal)) kcal" } ?? r.kcal.map { "\($0) kcal" } ?? "–", "pro Portion")
                tile(n.map { "\(Int($0.p)) · \(Int($0.kh)) · \(Int($0.f)) g" } ?? "–", "Eiweiß · KH · Fett")
                if kitchen.pantry.isEmpty {
                    tile("\(r.servings ?? 2)", "Portionen")
                } else {
                    let total = (r.ing ?? []).count
                    tile("\(max(0, total - missing.count)) von \(total)", "Zutaten im Vorrat")
                }
            }

            if let f = full {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ZUTATEN FÜR \(f.baseServings) PORTIONEN").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary)
                    VStack(spacing: 0) {
                        let ings = f.ingredients.filter { !$0.name.isEmpty }
                        ForEach(Array(ings.prefix(8).enumerated()), id: \.offset) { i, ing in
                            if i > 0 { Divider() }
                            HStack(spacing: 8) {
                                Text(ing.name).lineLimit(2)
                                if isMissing(ing.name) {
                                    Text("fehlt").font(.caption2.weight(.semibold)).foregroundColor(.orange)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                                }
                                Spacer(minLength: 8)
                                Text(ing.amount ?? "").foregroundColor(Theme.secondary).lineLimit(1)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 9)
                        }
                        Divider()
                        Button { dismiss(); onOpen(r.id) } label: {
                            HStack {
                                Text(ings.count > 8 ? "Alle \(ings.count) Zutaten und \(f.steps.count) Schritte" : "Rezept mit \(f.steps.count) Schritten öffnen")
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            }
                            .foregroundColor(Theme.accent).font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            }
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .id(r.id)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundColor(Theme.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .accessibilityElement(children: .combine)
    }

    private func dietLabel(_ r: RecipeSummary) -> String? {
        let d = r.diet ?? DietGuess.diet(r.ing ?? [])
        return d == "vegan" ? "vegan" : d == "vegetarisch" ? "vegetarisch" : nil
    }

    private func isMissing(_ name: String) -> Bool {
        guard !kitchen.pantry.isEmpty else { return false }
        return missing.contains { $0.lowercased() == name.lowercased() }
    }

    // MARK: Würfeln

    private func roll() {
        let list = pool
        guard !list.isEmpty else { return }
        var pick = list.randomElement()!
        if list.count > 1 { while pick.0.id == result?.id { pick = list.randomElement()! } }
        let keys = kitchen.pantry.map { FoodCatalog.key($0.name) }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            result = pick.0
            missing = keys.isEmpty ? [] : PantryMatch.missing(pick.0, pantry: keys)
            full = nil
            showPrefs = false
        }
        let id = pick.0.id
        Task {
            let r = await kitchen.recipe(id)
            if result?.id == id { full = r }
        }
    }
}
