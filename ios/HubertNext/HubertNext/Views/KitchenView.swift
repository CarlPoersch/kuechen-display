import SwiftUI

// ============================================================
// Küche: Rezepte · Woche · Einkauf · Vorrat · Airfryer
// Oben eine Segment-Steuerung wie in Apple-Apps. Alles gemeinsam im
// Haushalt; Abgleich alle 15 s, solange die Küche offen ist.
// ============================================================

enum KitchenTab: String, CaseIterable, Identifiable {
    case recipes = "Rezepte", week = "Woche", shop = "Einkauf", pantry = "Vorrat", airfryer = "Airfryer"
    var id: String { rawValue }
}

struct KitchenView: View {
    @EnvironmentObject var app: AppStore
    @ObservedObject private var kitchen = KitchenStore.shared
    @State var tab: KitchenTab = .recipes

    var body: some View {
        VStack(spacing: 0) {
            Picker("Bereich", selection: $tab) {
                ForEach(KitchenTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 10)
            .frame(maxWidth: 640)

            switch tab {
            case .recipes: RecipesTab()
            case .week: WeekTab()
            case .shop: ShopTab()
            case .pantry: PantryTab()
            case .airfryer: AirfryerTab()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { await kitchen.loadRecipes() }
        .refreshing(id: app.household?.id ?? "", every: { 15 }) {
            await KitchenStore.shared.sync(household: app.household?.id)
        }
    }
}

// MARK: Gemeinsame Bausteine

/// Sterne zum Antippen (nochmal auf denselben Stern = keine Bewertung)
struct StarRating: View {
    let value: Int?
    var size: CGFloat = 20
    var onChange: ((Int?) -> Void)? = nil
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= (value ?? 0) ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(i <= (value ?? 0) ? .orange : Color(UIColor.tertiaryLabel))
                    .onTapGesture { onChange?(value == i ? nil : i) }
            }
        }
        .allowsHitTesting(onChange != nil)   // nur antippbar, wo man bewerten kann
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bewertung: \(value ?? 0) von 5 Sternen")
    }
}

/// Weicher Knopf: primär (gefüllt) oder sekundär (graue Fläche)
struct SoftButton: View {
    let title: String
    let symbol: String
    var primary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundColor(primary ? .white : Theme.accent)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(primary ? Theme.accent : Color(UIColor.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }
}

/// "vor 3 Tagen" für den Kochverlauf
func cookedText(_ m: RecipeMeta) -> String? {
    guard let d = m.lastCookedDate else { return nil }
    let days = -Fmt.dayDiff(d)
    let when = days <= 0 ? "heute" : days == 1 ? "gestern" : "vor \(days) Tagen"
    return "Zuletzt gekocht \(when) · \(m.cookedCount)×"
}

// MARK: Rezepte

struct RecipesTab: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var query = ""
    @State private var filter = "Alle"
    @State private var cuisine = "Alle"
    @State private var suggestion: RecipeSummary?
    @State private var sheet: Sheet?
    private let filters = ["Alle", "Eigene", "Airfryer", "Schnell", "Favoriten", "Lange nicht"]

    enum Sheet: String, Identifiable { case new, link, cookbook, stats; var id: String { rawValue } }

    private var list: [RecipeSummary] {
        kitchen.recipes.filter { r in
            let q = query.lowercased()
            let match = q.isEmpty || r.title.lowercased().contains(q) || (r.cuisine ?? "").lowercased().contains(q)
                || (r.ing ?? []).contains { $0.lowercased().contains(q) }
            guard match else { return false }
            if cuisine != "Alle" && (r.cuisine ?? "Sonstige") != cuisine { return false }
            let m = kitchen.meta[r.id]
            switch filter {
            case "Eigene": return r.owner != nil
            case "Airfryer": return r.airfryer == true
            case "Schnell": return (r.minutes ?? 99) <= 30
            case "Favoriten": return (m?.rating ?? 0) >= 4
            case "Lange nicht": return m?.lastCookedDate.map { Date().timeIntervalSince($0) > 21 * 86400 } ?? true
            default: return true
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
                        TextField("Rezept oder Zutat suchen", text: $query).disableAutocorrection(true)
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Theme.secondary) }
                                .buttonStyle(.borderless)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                    roundButton("die.face.5.fill", "Zufallsrezept") { shuffle() }
                    roundButton("chart.bar.fill", "Koch-Statistik") { sheet = .stats }
                    Menu {
                        Button { sheet = .new } label: { Label("Neues Rezept", systemImage: "square.and.pencil") }
                        Button { sheet = .link } label: { Label("Rezept aus Link", systemImage: "link") }
                        Button { sheet = .cookbook } label: { Label("Familien-Kochbuch", systemImage: "book.closed") }
                    } label: {
                        Image(systemName: "plus").font(.headline).foregroundColor(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(Theme.accent))
                    }
                    .accessibilityLabel("Rezept hinzufügen")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { f in
                            Button { filter = f } label: {
                                Text(f).font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .foregroundColor(filter == f ? .white : .primary)
                                    .background(Capsule().fill(filter == f ? Theme.accent : Theme.card))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Länder / Küchen
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([("Alle", kitchen.recipes.count)] + cuisines, id: \.0) { c in
                            Button { withAnimation { cuisine = c.0; suggestion = nil } } label: {
                                HStack(spacing: 5) {
                                    Text(c.0 == "Alle" ? "🌍" : Self.flag(c.0))
                                    Text(c.0 == "Alle" ? "Alle Länder" : c.0).font(.subheadline.weight(.medium))
                                    Text("\(c.1)").font(.caption).foregroundColor(cuisine == c.0 ? .white.opacity(0.8) : Theme.secondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .foregroundColor(cuisine == c.0 ? .white : .primary)
                                .background(Capsule().fill(cuisine == c.0 ? Theme.accent : Theme.card))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let r = suggestion { suggestionCard(r) }

                if kitchen.recipes.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if list.isEmpty {
                    Text("Keine passenden Rezepte").foregroundColor(Theme.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 14)], spacing: 14) {
                    ForEach(list) { r in
                        NavigationLink(destination: RecipeDetailView(id: r.id)) { RecipeCard(recipe: r) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .new: NewRecipeSheet()
            case .link: ImportLinkSheet()
            case .cookbook: CookbookSheet()
            case .stats: KitchenStatsView()
            }
        }
    }

    /// Küchen mit Anzahl, die häufigsten zuerst
    private var cuisines: [(String, Int)] {
        Dictionary(grouping: kitchen.recipes) { $0.cuisine ?? "Sonstige" }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
    }

    static func flag(_ c: String) -> String {
        ["Deutsch": "🇩🇪", "Chinesisch": "🇨🇳", "Italienisch": "🇮🇹", "Indisch": "🇮🇳", "Japanisch": "🇯🇵",
         "Thailändisch": "🇹🇭", "Mediterran": "🫒", "Orientalisch": "🧆", "Koreanisch": "🇰🇷", "Mexikanisch": "🇲🇽",
         "Vietnamesisch": "🇻🇳", "Französisch": "🇫🇷", "Amerikanisch": "🇺🇸", "Griechisch": "🇬🇷", "Spanisch": "🇪🇸",
         "Türkisch": "🇹🇷", "Österreichisch": "🇦🇹", "International": "🌍"][c] ?? "🍽️"
    }

    /// Zufallsrezept aus den gerade gefilterten Rezepten (nicht zweimal dasselbe hintereinander)
    private func shuffle() {
        let pool = list.isEmpty ? kitchen.recipes : list
        guard !pool.isEmpty else { return }
        var pick = pool.randomElement()!
        if pool.count > 1 { while pick.id == suggestion?.id { pick = pool.randomElement()! } }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { suggestion = pick }
    }

    private func suggestionCard(_ r: RecipeSummary) -> some View {
        HStack(spacing: 16) {
            Text(r.icon).font(.system(size: 54))
            VStack(alignment: .leading, spacing: 4) {
                Text("🎲 ZUFALLSREZEPT" + (cuisine == "Alle" ? "" : " · " + cuisine.uppercased()))
                    .font(.caption.weight(.semibold)).foregroundColor(Theme.accent)
                Text(r.title).font(.title3.weight(.bold)).lineLimit(2)
                Text([r.cuisine, r.time].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundColor(Theme.secondary)
                if let c = kitchen.meta[r.id].flatMap(cookedText) { Text(c).font(.caption).foregroundColor(Theme.secondary) }
                HStack(spacing: 10) {
                    NavigationLink(destination: RecipeDetailView(id: r.id)) {
                        Text("Ansehen").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8).background(Capsule().fill(Theme.accent))
                    }
                    Button { shuffle() } label: {
                        Label("Anderes", systemImage: "arrow.triangle.2.circlepath").font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
                    }
                    Button { withAnimation { suggestion = nil } } label: {
                        Image(systemName: "xmark").font(.subheadline.weight(.semibold)).foregroundColor(Theme.secondary)
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Vorschlag schließen")
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.accent.opacity(0.35), lineWidth: 1.5))
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    private func roundButton(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.headline).foregroundColor(Theme.accent)
                .frame(width: 40, height: 40).background(Circle().fill(Color(UIColor.tertiarySystemFill)))
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct RecipeCard: View {
    let recipe: RecipeSummary
    @ObservedObject private var kitchen = KitchenStore.shared

    var body: some View {
        let m = kitchen.meta[recipe.id]
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(recipe.icon).font(.system(size: 40))
                Spacer()
                if recipe.airfryer == true {
                    Image(systemName: "flame.fill").font(.caption).foregroundColor(.white)
                        .padding(6).background(Circle().fill(Color.orange))
                        .accessibilityLabel("Airfryer")
                }
            }
            Text(recipe.title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
            if let o = recipe.owner {
                Label(o, systemImage: o == "Eigenes" ? "person.fill" : "book.closed").font(.caption2.weight(.semibold))
                    .foregroundColor(Theme.accent)
            }
            Text([recipe.cuisine, recipe.time].compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
            Spacer(minLength: 0)
            if let r = m?.rating { StarRating(value: r, size: 11) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: Rezept

struct RecipeDetailView: View {
    let id: String
    @ObservedObject private var kitchen = KitchenStore.shared
    @ObservedObject private var timers = TimerCenter.shared
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var recipe: Recipe?
    @State private var portions = 2
    @State private var cooking = false
    @State private var planning = false
    @State private var note = ""
    @State private var toast: String?
    @State private var editing = false

    var body: some View {
        ScrollView {
            if let r = recipe {
                VStack(alignment: .leading, spacing: 20) {
                    header(r)
                    if hSize == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            ingredients(r).frame(maxWidth: 340)
                            steps(r)
                        }
                    } else {
                        ingredients(r)
                        steps(r)
                    }
                    notes(r)
                }
                .padding()
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(recipe?.title ?? "Rezept")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .overlay(alignment: .bottom) {
            if let t = toast {
                Text(t).font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(.regularMaterial)).padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            recipe = await kitchen.recipe(id)
            if let r = recipe { portions = r.baseServings }
            note = kitchen.metaFor(id).note
        }
        .onDisappear { if note != kitchen.metaFor(id).note { kitchen.setNote(id, note) } }
        .fullScreenCover(isPresented: $cooking) {
            if let r = recipe { CookModeView(recipe: r, portions: portions) }
        }
        .sheet(isPresented: $planning) {
            if let r = recipe { PlanSheet(recipeId: r.id, title: r.title, portions: portions) }
        }
        .sheet(isPresented: $editing, onDismiss: { Task { recipe = await kitchen.recipe(id) } }) {
            if let r = recipe { NewRecipeSheet(recipe: r) }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if kitchen.isMine(id) {
                    Button("Bearbeiten") { editing = true }
                } else if let r = recipe, r.isOwn {
                    // Aus einem fremden Kochbuch: als eigenes Rezept übernehmen
                    Button("Kopieren") { var c = r; c.id = ""; kitchen.saveOwn(c); show("In euer Kochbuch kopiert") }
                }
            }
        }
    }

    private func show(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toast = nil } }
    }

    private func header(_ r: Recipe) -> some View {
        let m = kitchen.metaFor(r.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Text(r.icon).font(.system(size: 60))
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.title).font(.system(size: 28, weight: .bold))
                    Text([r.cuisine, r.time].compactMap { $0 }.joined(separator: " · ")).foregroundColor(Theme.secondary)
                    if let src = r.source, let host = URL(string: src)?.host {
                        Label(host.replacingOccurrences(of: "www.", with: ""), systemImage: "link").font(.caption).foregroundColor(Theme.secondary)
                    }
                    HStack(spacing: 10) {
                        StarRating(value: m.rating) { kitchen.setRating(r.id, $0) }
                        if let c = cookedText(m) { Text(c).font(.caption).foregroundColor(Theme.secondary) }
                    }
                }
            }
            HStack(spacing: 10) {
                SoftButton(title: "Kochen", symbol: "play.fill", primary: true) { cooking = true }
                SoftButton(title: "Planen", symbol: "calendar.badge.plus") { planning = true }
                SoftButton(title: "Einkaufen", symbol: "cart.badge.plus") {
                    let n = kitchen.addMissing(r, portions: portions)
                    show(n == 0 ? "Alles da – nichts fehlt" : "\(n) Zutaten auf der Einkaufsliste")
                }
            }
        }
    }

    private func ingredients(_ r: Recipe) -> some View {
        let factor = Double(portions) / Double(r.baseServings)
        let groups = Dictionary(grouping: r.ingredients) { $0.group ?? "" }
        let order = r.ingredients.reduce(into: [String]()) { if !$0.contains($1.group ?? "") { $0.append($1.group ?? "") } }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ZUTATEN").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary)
                Spacer()
                Stepper("\(portions) Portionen", value: $portions, in: 1...20).font(.subheadline).fixedSize()
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(order, id: \.self) { g in
                    if !g.isEmpty {
                        Text(g).font(.subheadline.weight(.semibold)).padding(.top, 10).padding(.bottom, 4)
                    }
                    ForEach(Array((groups[g] ?? []).enumerated()), id: \.offset) { i, ing in
                        if i > 0 { Divider() }
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(Amount.scale(ing.amount, factor)).font(.body.monospacedDigit().weight(.semibold))
                                .frame(width: 86, alignment: .leading)
                            Text(ing.name)
                            Spacer(minLength: 4)
                            if kitchen.inPantry(ing.name) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    .accessibilityLabel("Im Vorrat")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
            Label("Grüner Haken = im Vorrat", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundColor(Theme.secondary)
        }
    }

    private func steps(_ r: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ZUBEREITUNG").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(r.steps.enumerated()), id: \.offset) { i, s in
                    if i > 0 { Divider() }
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)").font(.headline).foregroundColor(.white)
                            .frame(width: 28, height: 28).background(Circle().fill(Theme.accent))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(s.text).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                if let m = s.minutes {
                                    Button { timers.start("\(r.title) · Schritt \(i + 1)", minutes: m) } label: {
                                        Label("\(Int(m)) Min. Timer", systemImage: "timer").font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 10).padding(.vertical, 5)
                                            .background(Capsule().fill(Theme.accent.opacity(0.12)))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            if let h = Airfryer.hint(for: s, recipeIsAirfryer: r.airfryer == true) {
                                Label(h, systemImage: "flame").font(.footnote).foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        }
    }

    private func notes(_ r: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTIZ").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary)
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("z. B. „lieber 2 Min. länger“").foregroundColor(Color(UIColor.placeholderText))
                        .padding(.horizontal, 5).padding(.vertical, 8)
                }
                TextEditor(text: $note).frame(minHeight: 90)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        }
    }
}

/// Rezept für einen der nächsten 7 Tage einplanen
struct PlanSheet: View {
    let recipeId: String
    let title: String
    @State var portions: Int
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var day = Calendar.current.startOfDay(for: Date())

    init(recipeId: String, title: String, portions: Int) {
        self.recipeId = recipeId; self.title = title; _portions = State(initialValue: portions)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tag")) {
                    ForEach(0..<7, id: \.self) { i in
                        let d = Calendar.current.date(byAdding: .day, value: i, to: Calendar.current.startOfDay(for: Date()))!
                        Button { day = d } label: {
                            HStack {
                                Text(Fmt.dayLabel(d)).foregroundColor(.primary)
                                Spacer()
                                if let first = kitchen.planned(on: d).first, let s = kitchen.summary(first.recipeId) {
                                    Text(s.icon + " " + s.title).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                                }
                                if Calendar.current.isDate(d, inSameDayAs: day) {
                                    Image(systemName: "checkmark").foregroundColor(Theme.accent)
                                }
                            }
                        }
                    }
                }
                Section { Stepper("\(portions) Portionen", value: $portions, in: 1...20) }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Einplanen") { kitchen.addToPlan(recipeId, on: day, portions: portions); dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Kochmodus

struct CookModeView: View {
    let recipe: Recipe
    let portions: Int
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @ObservedObject private var timers = TimerCenter.shared
    @State private var page = 0
    @State private var showIngredients = false
    @StateObject private var voice = SpeechControl()

    private var count: Int { recipe.steps.count + 1 }   // + Fertig-Seite

    /// Sprachbefehl ausführen
    private func run(_ c: CookCommand) {
        switch c {
        case .next: withAnimation { page = min(recipe.steps.count, page + 1) }
        case .back: withAnimation { page = max(0, page - 1) }
        case .ingredients: showIngredients = true
        case .timer:
            if page < recipe.steps.count, let m = recipe.steps[page].minutes,
               !timers.timers.contains(where: { $0.name.hasSuffix("Schritt \(page + 1)") }) {
                timers.start("\(recipe.title) · Schritt \(page + 1)", minutes: m)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Kopf: Schließen, Fortschritt, Zutaten
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                        .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                }
                Spacer()
                VStack(spacing: 4) {
                    Text(recipe.title).font(.headline).lineLimit(1)
                    Text(page < recipe.steps.count ? "Schritt \(page + 1) von \(recipe.steps.count)" : "Fertig")
                        .font(.subheadline).foregroundColor(Theme.secondary)
                }
                Spacer()
                Button { voice.toggle() } label: {
                    Image(systemName: voice.listening ? "mic.fill" : "mic.slash").font(.headline)
                        .foregroundColor(voice.listening ? .white : .primary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(voice.listening ? Theme.accent : Color(UIColor.tertiarySystemFill)))
                }
                .accessibilityLabel(voice.listening ? "Sprachsteuerung aus" : "Sprachsteuerung an")
                Button { showIngredients = true } label: {
                    Image(systemName: "list.bullet").font(.headline).frame(width: 44, height: 44)
                        .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                }
                .accessibilityLabel("Zutaten")
            }
            .buttonStyle(.plain)
            .padding(.horizontal).padding(.top, 10)
            ProgressView(value: Double(min(page + 1, recipe.steps.count)), total: Double(max(1, recipe.steps.count)))
                .tint(Theme.accent).padding(.horizontal).padding(.top, 10)
            if voice.listening || voice.problem != nil {
                Label(voice.problem ?? "Sag „weiter“, „zurück“, „Timer“ oder „Zutaten“" + (voice.heard.isEmpty ? "" : " · erkannt: „\(voice.heard)“"),
                      systemImage: voice.problem == nil ? "waveform" : "exclamationmark.triangle")
                    .font(.subheadline).foregroundColor(voice.problem == nil ? Theme.secondary : .orange)
                    .padding(.horizontal).padding(.top, 8)
            }

            // Laufende Timer
            if !timers.timers.isEmpty {
                VStack(spacing: 6) { ForEach(timers.timers) { TimerRow(timer: $0, compact: true) } }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                    .padding(.horizontal).padding(.top, 10)
            }

            TabView(selection: $page) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, s in
                    stepPage(i, s).tag(i)
                }
                donePage.tag(recipe.steps.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Weiter / Zurück
            HStack(spacing: 12) {
                SoftButton(title: "Zurück", symbol: "chevron.left") { withAnimation { page = max(0, page - 1) } }
                    .disabled(page == 0).opacity(page == 0 ? 0.4 : 1)
                if page < recipe.steps.count {
                    SoftButton(title: "Weiter", symbol: "chevron.right", primary: true) { withAnimation { page += 1 } }
                }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            voice.onCommand = { c in run(c) }
        }
        .onDisappear { voice.stop() }
        .sheet(isPresented: $showIngredients) { ingredientSheet }
        .overlay(TimerAlarmOverlay())
    }

    private func stepPage(_ i: Int, _ s: Recipe.Step) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(s.text).font(.system(size: 30, weight: .medium)).lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                if let m = s.minutes {
                    let running = timers.timers.contains { $0.name.hasSuffix("Schritt \(i + 1)") }
                    Button { timers.start("\(recipe.title) · Schritt \(i + 1)", minutes: m) } label: {
                        Label(running ? "Timer läuft" : "Timer \(Int(m)) Min. starten", systemImage: "timer")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 22).padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(Capsule().fill(running ? Color.gray : Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(running)
                }
                if let h = Airfryer.hint(for: s, recipeIsAirfryer: recipe.airfryer == true) {
                    Label(h, systemImage: "flame").font(.title3).foregroundColor(.orange)
                }
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var donePage: some View {
        VStack(spacing: 20) {
            Text(recipe.icon).font(.system(size: 90))
            Text("Guten Appetit!").font(.system(size: 34, weight: .bold))
            Text("Wie war's?").foregroundColor(Theme.secondary)
            StarRating(value: kitchen.metaFor(recipe.id).rating, size: 34) { kitchen.setRating(recipe.id, $0) }
            SoftButton(title: "Gekocht – fertig", symbol: "checkmark", primary: true) {
                kitchen.markCooked(recipe.id); dismiss()
            }
            .frame(maxWidth: 360)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ingredientSheet: some View {
        let factor = Double(portions) / Double(recipe.baseServings)
        return NavigationView {
            List(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ing in
                HStack {
                    Text(Amount.scale(ing.amount, factor)).font(.body.monospacedDigit().weight(.semibold)).frame(width: 90, alignment: .leading)
                    Text(ing.name)
                }
                .font(.title3)
            }
            .navigationTitle("Zutaten · \(portions) Portionen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showIngredients = false } } }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Woche

struct WeekTab: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var picking: Date?
    @State private var message: String?

    private var days: [Date] {
        (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date()))! }
    }

    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        let n = await kitchen.shoppingFromPlan()
                        message = n == 0 ? "Alles da – für die Woche fehlt nichts." : "\(n) Zutaten auf die Einkaufsliste gesetzt."
                    }
                } label: {
                    Label("Einkaufsliste für die Woche erstellen", systemImage: "cart.badge.plus").font(.headline)
                }
            } footer: {
                Text("Nimmt alle geplanten Rezepte der nächsten 7 Tage. Was im Vorrat ist oder schon auf der Liste steht, kommt nicht dazu.")
            }
            ForEach(days, id: \.self) { d in
                Section(header: Text(Fmt.dayLabel(d))) {
                    ForEach(kitchen.planned(on: d)) { e in
                        if let s = kitchen.summary(e.recipeId) {
                            NavigationLink(destination: RecipeDetailView(id: s.id)) {
                                HStack(spacing: 12) {
                                    Text(s.icon).font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.title).font(.headline)
                                        Text("\(e.portions) Portionen" + (s.time.map { " · " + $0 } ?? ""))
                                            .font(.caption).foregroundColor(Theme.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .swipeActions {
                                Button(role: .destructive) { kitchen.removeFromPlan(e) } label: { Label("Entfernen", systemImage: "trash") }
                            }
                            .contextMenu {
                                Button { kitchen.setPortions(e, e.portions + 1) } label: { Label("Portion mehr", systemImage: "plus") }
                                Button { kitchen.setPortions(e, e.portions - 1) } label: { Label("Portion weniger", systemImage: "minus") }
                                Button(role: .destructive) { kitchen.removeFromPlan(e) } label: { Label("Entfernen", systemImage: "trash") }
                            }
                        }
                    }
                    Button { picking = d } label: { Label("Rezept hinzufügen", systemImage: "plus") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: Binding(get: { picking.map { PickDay(date: $0) } }, set: { picking = $0?.date })) { p in
            RecipePicker { id in kitchen.addToPlan(id, on: p.date, portions: kitchen.summary(id)?.servings ?? 2) }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private struct PickDay: Identifiable { let date: Date; var id: Date { date } }
}

/// Rezept auswählen (Suche)
struct RecipePicker: View {
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var query = ""

    var body: some View {
        NavigationView {
            List(kitchen.recipes.filter { query.isEmpty || $0.title.lowercased().contains(query.lowercased()) }) { r in
                Button { onPick(r.id); dismiss() } label: {
                    HStack(spacing: 12) {
                        Text(r.icon).font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title).foregroundColor(.primary)
                            Text([r.cuisine, r.time].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundColor(Theme.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Rezept suchen")
            .navigationTitle("Rezept wählen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Einkauf

struct ShopTab: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var newItem = ""
    @State private var siri = false
    @FocusState private var typing: Bool

    var body: some View {
        let open = kitchen.shop.filter { !$0.done }
        let done = kitchen.shop.filter { $0.done }
        List {
            Section {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent).font(.title3)
                    TextField("Artikel hinzufügen, z. B. Milch", text: $newItem)
                        .focused($typing).submitLabel(.done)
                        .onSubmit { kitchen.add("shop", name: newItem); newItem = ""; typing = true }
                }
            }
            Section(header: Text(open.isEmpty ? "Alles eingekauft" : "Noch zu kaufen · \(open.count)")) {
                ForEach(open) { ShopRow(item: $0) }
            }
            if !done.isEmpty {
                Section(header: Text("Erledigt"), footer: Text("Nach links wischen: in den Vorrat legen.")) {
                    ForEach(done) { ShopRow(item: $0) }
                    Button(role: .destructive) { withAnimation { kitchen.clearDone() } } label: {
                        Label("Erledigte entfernen", systemImage: "trash")
                    }
                }
            }
            Section {
                Button { siri = true } label: { Label("Mit Siri hinzufügen …", systemImage: "mic.fill") }
            }
            if kitchen.failed {
                Section { Label("Gerade keine Verbindung – Änderungen werden nachgeholt", systemImage: "wifi.slash")
                    .font(.footnote).foregroundColor(Theme.secondary) }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $siri) { SiriSetupSheet() }
    }
}

struct ShopRow: View {
    let item: KitchenItem
    var compact = false
    @ObservedObject private var kitchen = KitchenStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Button { withAnimation { kitchen.toggle(item) } } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 20 : 24))
                    .foregroundColor(item.done ? .green : Color(UIColor.tertiaryLabel))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.done ? "Erledigt" : "Abhaken")
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(compact ? .subheadline : .body).strikethrough(item.done).foregroundColor(item.done ? Theme.secondary : .primary)
                    .lineLimit(1)
                let sub = [item.amount, item.recipe].filter { !$0.isEmpty }.joined(separator: " · ")
                if !sub.isEmpty && !compact { Text(sub).font(.caption).foregroundColor(Theme.secondary).lineLimit(1) }
            }
            Spacer(minLength: 0)
            if compact && !item.amount.isEmpty { Text(item.amount).font(.caption).foregroundColor(Theme.secondary) }
        }
        .padding(.vertical, compact ? 0 : 2)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { kitchen.delete(item) } label: { Label("Löschen", systemImage: "trash") }
            if item.done {
                Button { kitchen.moveToPantry(item) } label: { Label("In den Vorrat", systemImage: "archivebox") }.tint(.green)
            }
        }
    }
}

// MARK: Vorrat

struct PantryTab: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var newItem = ""
    @State private var place = "Vorrat"
    @State private var editing: KitchenItem?
    @State private var scanning = false

    var body: some View {
        List {
            Section {
                Button { scanning = true } label: {
                    Label("Barcode oder Kassenzettel scannen", systemImage: "barcode.viewfinder").font(.headline)
                }
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent).font(.title3)
                    TextField("Hinzufügen, z. B. Reis", text: $newItem)
                        .onSubmit { kitchen.add("pantry", name: newItem, place: place); newItem = "" }
                    Picker("Ort", selection: $place) { ForEach(KitchenStore.places, id: \.self) { Text($0) } }
                        .pickerStyle(.menu).labelsHidden()
                }
            }
            let soon = kitchen.pantry.filter { ($0.daysLeft ?? 99) <= 3 }
            if !soon.isEmpty {
                Section(header: Text("Bald aufbrauchen")) { ForEach(soon) { row($0) } }
            }
            ForEach(KitchenStore.places, id: \.self) { p in
                let list = kitchen.pantry.filter { ($0.place.isEmpty ? "Vorrat" : $0.place) == p }
                    .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                if !list.isEmpty {
                    Section(header: Text("\(p) · \(list.count)")) { ForEach(list) { row($0) } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editing) { PantryEditSheet(item: $0) }
        .sheet(isPresented: $scanning) { ScanSheet() }
    }

    private func row(_ it: KitchenItem) -> some View {
        Button { editing = it } label: {
            HStack {
                Text(it.name).foregroundColor(.primary)
                Spacer()
                if let d = it.daysLeft {
                    Text(d < 0 ? "abgelaufen" : d == 0 ? "heute" : d == 1 ? "morgen" : "noch \(d) Tage")
                        .font(.subheadline).foregroundColor(d <= 1 ? .red : d <= 3 ? .orange : Theme.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { kitchen.delete(it) } label: { Label("Löschen", systemImage: "trash") }
            Button { kitchen.add("shop", name: it.name) } label: { Label("Einkaufen", systemImage: "cart.badge.plus") }.tint(Theme.accent)
        }
    }
}

struct PantryEditSheet: View {
    @State var item: KitchenItem
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var hasDate: Bool
    @State private var date: Date

    init(item: KitchenItem) {
        _item = State(initialValue: item)
        _hasDate = State(initialValue: item.mhdDate != nil)
        _date = State(initialValue: item.mhdDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $item.name)
                Picker("Ort", selection: $item.place) { ForEach(KitchenStore.places, id: \.self) { Text($0) } }
                Toggle("Mindesthaltbarkeit", isOn: $hasDate.animation())
                if hasDate { DatePicker("Haltbar bis", selection: $date, displayedComponents: .date) }
                Section {
                    Button { kitchen.add("shop", name: item.name); dismiss() } label: { Label("Auf die Einkaufsliste", systemImage: "cart.badge.plus") }
                    Button(role: .destructive) { kitchen.delete(item); dismiss() } label: { Label("Aufgebraucht – entfernen", systemImage: "trash") }
                }
            }
            .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if item.place.isEmpty { item.place = "Vorrat" }
                        item.mhd = hasDate ? KitchenStore.day.string(from: date) : nil
                        kitchen.update(item); dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Airfryer

struct AirfryerTab: View {
    @State private var oven = 200
    @State private var minutes = 25
    @State private var query = ""

    var body: some View {
        let a = Airfryer.fromOven(celsius: oven, minutes: minutes)
        let rows = Airfryer.table.filter { query.isEmpty || $0.1.lowercased().contains(query.lowercased()) }
        List {
            Section(header: Text("Backofen-Rezept umrechnen"),
                    footer: Text("Faustregel: 20 °C weniger und etwa 20 % kürzer. Gegen Ende reinschauen – jeder Airfryer heizt anders.")) {
                Stepper("Backofen: \(oven) °C", value: $oven, in: 100...250, step: 10)
                Stepper("Backzeit: \(minutes) Min.", value: $minutes, in: 1...180)
                HStack {
                    Label("Airfryer", systemImage: "flame.fill").foregroundColor(.orange).font(.headline)
                    Spacer()
                    Text("\(a.celsius) °C · \(a.minutes) Min.").font(.title3.weight(.bold).monospacedDigit())
                }
                .padding(.vertical, 4)
            }
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
                    TextField("Spickzettel durchsuchen, z. B. Pommes", text: $query)
                }
            }
            ForEach(Array(Set(rows.map { $0.0 })).sorted(), id: \.self) { g in
                Section(header: Text(g)) {
                    ForEach(rows.filter { $0.0 == g }, id: \.1) { r in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.1).font(.headline)
                                Text(r.4).font(.caption).foregroundColor(Theme.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(r.2 + " °C").font(.headline).foregroundColor(Theme.accent)
                                Text(r.3 + " Min.").font(.subheadline.monospacedDigit())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
