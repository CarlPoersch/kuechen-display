import SwiftUI
import Combine

// ============================================================
// Küche: Rezepte · Woche · Einkauf · Vorrat (Airfryer ist ein Filter bei den Rezepten)
// Oben eine Segment-Steuerung wie in Apple-Apps. Alles gemeinsam im
// Haushalt; Abgleich alle 15 s, solange die Küche offen ist.
// ============================================================

enum KitchenTab: String, CaseIterable, Identifiable {
    case recipes = "Rezepte", week = "Woche", shop = "Einkauf", pantry = "Vorrat"
    var id: String { rawValue }
}

struct KitchenView: View {
    @EnvironmentObject var app: AppStore
    @ObservedObject private var kitchen = KitchenStore.shared
    @State var tab: KitchenTab = .recipes
    @ObservedObject private var jump = RecipeJump.shared

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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { await kitchen.loadRecipes(); await NutritionCalc.shared.load() }
        .refreshing(id: app.household?.id ?? "", every: { 15 }) {
            await KitchenStore.shared.sync(household: app.household?.id)
        }
        // „Rezepte mit …“ aus dem Vorrat (Tab oder Startseite) → zu den Rezepten wechseln
        .onAppear { if jump.pending != nil { tab = .recipes } }
        .onChange(of: jump.pending) { if $0 != nil { withAnimation { tab = .recipes } } }
    }
}

/// „Rezepte mit …“: Zutat aus dem Vorrat an die Rezeptsuche übergeben
final class RecipeJump: ObservableObject {
    static let shared = RecipeJump()
    @Published var pending: String?
    func show(_ ingredient: String) { pending = ingredient }
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
    @State private var filter = RecipeFilter(diet: DietPreference.kitchen)   // Voreinstellung der Küche, sonst „Alle“
    @AppStorage("hubert.diet.kitchen") private var dietPref = "Alle"
    @AppStorage("hubert.kitchen.daily") private var showDaily = true          // Rezept des Tages oben
    @AppStorage("hubert.kitchen.dailyAsked") private var dailyAsked = false   // beim ersten Öffnen gefragt?
    @State private var askDaily = false
    @State private var showFilter = false
    @State private var sheet: Sheet?
    @State private var pendingOpen: String?      // aus Statistik/Würfel gewählt – öffnet nach dem Schließen
    @State private var pendingCook: (Recipe, Int)?
    @State private var openId = ""
    @State private var opening = false
    @State private var openAirfryer = false
    @ObservedObject private var session = CookSession.shared

    enum Sheet: String, Identifiable { case new, link, cookbook, stats, dice; var id: String { rawValue } }

    @ObservedObject private var jump = RecipeJump.shared
    @ObservedObject private var launch = KitchenLaunch.shared

    /// Von der Küchen-Karte: Rezept direkt öffnen oder den Würfel zeigen
    private func takeLaunch() {
        if let id = launch.recipe { launch.recipe = nil; openId = id; opening = true }
        if launch.dice { launch.dice = false; sheet = .dice }
    }

    /// Zutat aus dem Vorrat: Suche leeren, nur diese Zutat als Filter (Ernährung bleibt)
    private func takeJump() {
        guard let z = jump.pending else { return }
        jump.pending = nil
        query = ""
        var f = RecipeFilter(diet: filter.diet)
        f.include = [z]
        withAnimation { filter = f }
    }

    private func matching(_ f: RecipeFilter) -> [(RecipeSummary, [String])] { f.apply(kitchen.recipes, query: query) }

    private var favs: Bool { filter.collection == "Favoriten" }

    var body: some View {
        let results = matching(filter)   // einmal pro Zeichnen
        let chips = filter.chips
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                searchRow(active: chips.count)

                // Rezept des Tages – schmale Zeile, nur ohne Suche/Filter (abschaltbar unter ⋯)
                if showDaily && query.isEmpty && filter == RecipeFilter(diet: dietPref), let r = kitchen.recipeOfTheDay() {
                    NavigationLink(destination: RecipeDetailView(id: r.id)) { dailyRow(r) }
                        .buttonStyle(.plain)
                }

                // Aktive Filter – nur sichtbar, wenn etwas gesetzt ist; antippen entfernt
                if !chips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(chips.enumerated()), id: \.offset) { _, c in
                                Button { withAnimation { c.clear(&filter) } } label: {
                                    HStack(spacing: 4) {
                                        Text(c.label).font(.subheadline.weight(.medium)).lineLimit(1)
                                        Image(systemName: "xmark").font(.caption2.weight(.bold))
                                    }
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 12).frame(minHeight: 32)
                                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Filter \(c.label) entfernen")
                            }
                            Button("Alle löschen") { withAnimation { filter = RecipeFilter() } }
                                .font(.subheadline).buttonStyle(.borderless)
                        }
                    }
                }

                // Airfryer gewählt: Umrechner gleich mit anbieten
                if filter.airfryer { airfryerHint }

                if kitchen.recipes.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if results.isEmpty {
                    VStack(spacing: 10) {
                        Text(filter.pantry && kitchen.pantry.isEmpty ? "Trag im Vorrat ein, was du da hast – dann zeigt Hubert, was sich damit kochen lässt."
                             : favs && kitchen.favorites.isEmpty ? "Noch keine Favoriten – tippe in einem Rezept auf das Herz oder halte eines gedrückt."
                             : "Keine passenden Rezepte").foregroundColor(Theme.secondary).multilineTextAlignment(.center)
                        if filter.isActive || !query.isEmpty {
                            Button("Filter zurücksetzen") { withAnimation { filter = RecipeFilter(); query = "" } }
                                .buttonStyle(.borderless)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    Text(results.count == 1 ? "1 Rezept" : "\(results.count) Rezepte")
                        .font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary)
                    // Kacheln auf allen Geräten (iPhone zwei Spalten, iPad mehr)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                        ForEach(results, id: \.0.id) { item in
                            NavigationLink(destination: RecipeDetailView(id: item.0.id)) {
                                RecipeCard(recipe: item.0, missing: filter.pantry ? item.1 : nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 84)      // Platz für die Plus-Taste unten rechts
        }
        .overlay(alignment: .bottomTrailing) { addButton }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Favoriten: nur Favoriten zeigen
                Button { withAnimation(.easeOut(duration: 0.2)) { filter.collection = favs ? "Alle" : "Favoriten" } } label: {
                    Image(systemName: favs ? "heart.fill" : "heart")
                }
                .accessibilityLabel(favs ? "Alle Rezepte zeigen" : "Nur Favoriten zeigen")
                Button { sheet = .dice } label: { Image(systemName: "die.face.5") }
                    .accessibilityLabel("Rezept würfeln")
                Menu {
                    Button { sheet = .stats } label: { Label("Koch-Statistik", systemImage: "chart.bar") }
                    Button { openAirfryer = true } label: { Label("Airfryer umrechnen", systemImage: "thermometer") }
                    Toggle(isOn: $showDaily) { Label("Rezept des Tages zeigen", systemImage: "sun.max") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Mehr")
            }
        }
        .onChange(of: dietPref) { filter.diet = $0 }
        .onAppear {
            let fromCard = launch.recipe != nil || launch.dice
            takeJump()
            takeLaunch()
            if !dailyAsked && !fromCard { askDaily = true }
        }
        .onChange(of: launch.recipe) { _ in takeLaunch() }
        .onChange(of: launch.dice) { _ in takeLaunch() }
        .onChange(of: jump.pending) { _ in takeJump() }
        .alert("Rezept des Tages anzeigen?", isPresented: $askDaily) {
            Button("Ja, gerne") { showDaily = true; dailyAsked = true }
            Button("Nein") { showDaily = false; dailyAsked = true }
        } message: {
            Text("Oben in der Küche steht dann jeden Tag ein Vorschlag. Ändern kannst du das jederzeit unter „⋯“.")
        }
        .sheet(isPresented: $showFilter) { RecipeFilterSheet(filter: $filter) { matching($0).count } }
        .sheet(item: $sheet, onDismiss: {
            // Erst wenn das Blatt zu ist, das Rezept öffnen bzw. kochen (sonst liegt es darunter)
            if let c = pendingCook {
                pendingCook = nil
                session.start(c.0, portions: c.1)
            } else if let id = pendingOpen {
                pendingOpen = nil
                openId = id
                opening = true
            }
        }) { s in
            switch s {
            case .new: NewRecipeSheet()
            case .link: ImportLinkSheet()
            case .cookbook: CookbookSheet()
            case .stats: KitchenStatsView { pendingOpen = $0 }
            case .dice: RecipeDiceSheet(onOpen: { pendingOpen = $0 }, onCook: { pendingCook = ($0, $1) })
            }
        }
        .background(
            ZStack {
                NavigationLink(destination: RecipeDetailView(id: openId).id(openId), isActive: $opening) { EmptyView() }
                NavigationLink(destination: AirfryerTab().navigationTitle("Airfryer").navigationBarTitleDisplayMode(.inline),
                               isActive: $openAirfryer) { EmptyView() }
            }
            .hidden()
        )
    }

    /// Suche + Filter-Knopf (mit Zahl der aktiven Filter)
    private func searchRow(active: Int) -> some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
                TextField("Rezept oder Zutat suchen", text: $query).disableAutocorrection(true)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Theme.secondary) }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Suche löschen")
                }
            }
            .padding(10)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
            Button { showFilter = true } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.headline).foregroundColor(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(active > 0 ? Theme.accent.opacity(0.14) : Color(UIColor.tertiarySystemFill)))
                    .overlay(alignment: .topTrailing) {
                        if active > 0 {
                            Text("\(active)").font(.caption2.weight(.bold)).foregroundColor(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Capsule().fill(Theme.accent))
                                .offset(x: 5, y: -5)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(active > 0 ? "Filter, \(active) aktiv" : "Filter")
        }
    }

    private func dailyRow(_ r: RecipeSummary) -> some View {
        HStack(spacing: 12) {
            Text(r.icon).font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
            VStack(alignment: .leading, spacing: 1) {
                Text("Rezept des Tages").font(.caption.weight(.semibold)).foregroundColor(Theme.accent)
                Text(r.title).font(.body.weight(.semibold)).foregroundColor(.primary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let t = r.minutes { Text(RecipeRow.duration(t)).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1) }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .accessibilityElement(children: .combine)
    }

    private var airfryerHint: some View {
        Button { openAirfryer = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "thermometer").font(.headline).foregroundColor(.orange)
                    .frame(width: 32, height: 32).background(Circle().fill(Color.orange.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Backofen umrechnen & Garzeiten").font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                    Text("Temperatur, Zeit und Spickzettel für den Airfryer").font(.caption).foregroundColor(Theme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        }
        .buttonStyle(.plain)
    }

    static func flag(_ c: String) -> String {
        ["Deutsch": "🇩🇪", "Chinesisch": "🇨🇳", "Italienisch": "🇮🇹", "Indisch": "🇮🇳", "Japanisch": "🇯🇵",
         "Thailändisch": "🇹🇭", "Mediterran": "🫒", "Orientalisch": "🧆", "Koreanisch": "🇰🇷", "Mexikanisch": "🇲🇽",
         "Vietnamesisch": "🇻🇳", "Französisch": "🇫🇷", "Amerikanisch": "🇺🇸", "Griechisch": "🇬🇷", "Spanisch": "🇪🇸",
         "Türkisch": "🇹🇷", "Österreichisch": "🇦🇹", "International": "🌍", "Britisch": "🇬🇧", "Schweizerisch": "🇨🇭",
         "Skandinavisch": "🇸🇪", "Ungarisch": "🇭🇺", "Polnisch": "🇵🇱", "Portugiesisch": "🇵🇹", "Libanesisch": "🇱🇧",
         "Marokkanisch": "🇲🇦", "Persisch": "🇮🇷", "Indonesisch": "🇮🇩", "Karibisch": "🌴", "Brasilianisch": "🇧🇷",
         "Peruanisch": "🇵🇪", "Äthiopisch": "🇪🇹", "Russisch": "🇷🇺", "Tschechisch": "🇨🇿", "Israelisch": "🇮🇱", "Malaysisch": "🇲🇾",
         "Argentinisch": "🇦🇷", "Kolumbianisch": "🇨🇴", "Kubanisch": "🇨🇺", "Kanadisch": "🇨🇦", "Bosnisch": "🇧🇦",
         "Bulgarisch": "🇧🇬", "Schwedisch": "🇸🇪", "Finnisch": "🇫🇮", "Niederländisch": "🇳🇱", "Belgisch": "🇧🇪",
         "Australisch": "🇦🇺", "Georgisch": "🇬🇪", "Ukrainisch": "🇺🇦", "Palästinensisch": "🇵🇸", "Syrisch": "🇸🇾",
         "Ägyptisch": "🇪🇬", "Nigerianisch": "🇳🇬", "Senegalesisch": "🇸🇳", "Südafrikanisch": "🇿🇦", "Pakistanisch": "🇵🇰",
         "Sri-Lankisch": "🇱🇰", "Philippinisch": "🇵🇭", "Singapurisch": "🇸🇬", "Taiwanisch": "🇹🇼", "Bayerisch": "🥨",
         "Schwäbisch": "🥨", "Asiatisch": "🥢", "Osteuropäisch": "🥟"][c] ?? "🍽️"
    }

    /// Einzige schwebende Taste: Rezept hinzufügen
    private var addButton: some View {
        Menu {
            Button { sheet = .new } label: { Label("Neues Rezept", systemImage: "square.and.pencil") }
            Button { sheet = .link } label: { Label("Rezept aus Link", systemImage: "link") }
            Button { sheet = .cookbook } label: { Label("Familien-Kochbuch", systemImage: "book.closed") }
        } label: {
            Image(systemName: "plus").font(.system(size: 24, weight: .semibold)).foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Theme.accent))
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .accessibilityLabel("Rezept hinzufügen")
        .padding(.trailing, 20).padding(.bottom, 20)
    }
}

/// Rezept als Listenzeile (iPhone): Emoji klein, Titel, „Land · Zeit · kcal“, Herz nur bei Favoriten
struct RecipeRow: View {
    let recipe: RecipeSummary
    var missing: [String]? = nil
    @ObservedObject private var kitchen = KitchenStore.shared

    static func duration(_ m: Int) -> String {
        m < 60 ? "\(m) Min." : m % 60 == 0 ? "\(m / 60) Std." : "\(m / 60) Std. \(m % 60) Min."
    }

    var body: some View {
        let fav = kitchen.isFavorite(recipe.id)
        HStack(spacing: 12) {
            Text(recipe.icon).font(.system(size: 26))
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title).font(.body.weight(.semibold)).foregroundColor(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text(meta).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                if let miss = missing {
                    Label(miss.isEmpty ? "Alles da" : "Fehlt: " + miss.prefix(2).joined(separator: ", ") + (miss.count > 2 ? " +\(miss.count - 2)" : ""),
                          systemImage: miss.isEmpty ? "checkmark.circle.fill" : "cart")
                        .font(.caption.weight(.semibold)).lineLimit(1)
                        .foregroundColor(miss.isEmpty ? .green : Theme.secondary)
                }
            }
            Spacer(minLength: 6)
            if fav { Image(systemName: "heart.fill").font(.caption).foregroundColor(Theme.accent).accessibilityLabel("Favorit") }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(minHeight: 66)
        .contentShape(Rectangle())
        .contextMenu {
            Button { kitchen.toggleFavorite(recipe.id) } label: {
                fav ? Label("Aus Favoriten entfernen", systemImage: "heart.slash") : Label("Zu Favoriten", systemImage: "heart")
            }
        }
    }

    private var meta: String {
        var parts: [String] = []
        if let c = recipe.cuisine { parts.append(c) }
        if let m = recipe.minutes { parts.append(Self.duration(m)) } else if let t = recipe.time { parts.append(t) }
        if let k = recipe.kcal { parts.append("\(k) kcal") }
        if let o = recipe.owner { parts.insert(o, at: 0) }
        return parts.joined(separator: " · ")
    }
}

/// Große Umschalt-Kachel (Schnellwahl über den Kategorien)
/// Herz zum Merken. Eigener Knopf, damit er in Karten nicht das Rezept öffnet.
struct FavoriteButton: View {
    let id: String
    var size: CGFloat = 15
    @ObservedObject private var kitchen = KitchenStore.shared
    var body: some View {
        let on = kitchen.isFavorite(id)
        Button { withAnimation(.easeOut(duration: 0.15)) { kitchen.toggleFavorite(id) } } label: {
            Image(systemName: on ? "heart.fill" : "heart")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(on ? Theme.accent : Theme.secondary)
                .frame(width: max(36, size * 2.4), height: max(36, size * 2.4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(on ? "Aus Favoriten entfernen" : "Zu Favoriten")
    }
}

struct QuickTile: View {
    let emoji: String
    let title: String
    let detail: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(emoji).font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    Text(detail).font(.caption).lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundColor(on ? .white.opacity(0.85) : Theme.secondary)
                }
                Spacer(minLength: 0)
                if on { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
            }
            .foregroundColor(on ? .white : .primary)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Theme.accent : Theme.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title + ", " + detail + (on ? ", eingeschaltet" : ""))
    }
}

struct RecipeCard: View {
    let recipe: RecipeSummary
    var missing: [String]? = nil      // nur bei „Mit meinem Vorrat“
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
                FavoriteButton(id: recipe.id).padding(.top, -8).padding(.trailing, -10)
            }
            Text(recipe.title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
            if let o = recipe.owner {
                Label(o, systemImage: o == "Eigenes" ? "person.fill" : "book.closed").font(.caption2.weight(.semibold))
                    .foregroundColor(Theme.accent)
            }
            Text([recipe.cuisine, recipe.time].compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
            if let k = recipe.kcal { Text("\(k) kcal").font(.caption).foregroundColor(Theme.secondary) }
            Spacer(minLength: 0)
            if let miss = missing {
                Label(miss.isEmpty ? "Alles da" : "Fehlt: " + miss.prefix(2).joined(separator: ", ") + (miss.count > 2 ? " +\(miss.count - 2)" : ""),
                      systemImage: miss.isEmpty ? "checkmark.circle.fill" : "cart")
                    .font(.caption2.weight(.semibold)).lineLimit(1)
                    .foregroundColor(miss.isEmpty ? .green : Theme.secondary)
            }
            if let r = m?.rating { StarRating(value: r, size: 11) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            Button { kitchen.toggleFavorite(recipe.id) } label: {
                kitchen.isFavorite(recipe.id) ? Label("Aus Favoriten entfernen", systemImage: "heart.slash")
                                              : Label("Zu Favoriten", systemImage: "heart")
            }
        }
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
    @ObservedObject private var session = CookSession.shared
    @ObservedObject private var nutrition = NutritionCalc.shared
    @State private var replaceCooking = false
    @State private var confirmCancel = false
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
                            VStack(alignment: .leading, spacing: 20) {
                                ingredients(r)
                                nutritionCard(r)
                            }
                            .frame(maxWidth: 340)
                            steps(r)
                        }
                    } else {
                        ingredients(r)
                        nutritionCard(r)
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
            if !nutrition.ready { await nutrition.load() }
            note = kitchen.metaFor(id).note
        }
        .onDisappear { if note != kitchen.metaFor(id).note { kitchen.setNote(id, note) } }
        .cancelCookingAlert($confirmCancel)
        .alert("Anderes Rezept wird gekocht", isPresented: $replaceCooking) {
            Button("Abbrechen", role: .cancel) {}
            Button("Wechseln") { if let r = recipe { session.start(r, portions: portions) } }
        } message: {
            Text("„\(session.recipe?.title ?? "")“ ist noch offen. Stattdessen dieses Rezept kochen?")
        }
        .sheet(isPresented: $planning) {
            if let r = recipe { PlanSheet(recipeId: r.id, title: r.title, portions: portions) }
        }
        .sheet(isPresented: $editing, onDismiss: { Task { recipe = await kitchen.recipe(id) } }) {
            if let r = recipe { NewRecipeSheet(recipe: r) }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let on = !kitchen.isFavorite(id)
                    kitchen.toggleFavorite(id)
                    show(on ? "Zu Favoriten hinzugefügt" : "Aus Favoriten entfernt")
                } label: { Image(systemName: kitchen.isFavorite(id) ? "heart.fill" : "heart") }
                .accessibilityLabel(kitchen.isFavorite(id) ? "Aus Favoriten entfernen" : "Zu Favoriten")
            }
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
                    Text([r.cuisine, r.time, nutrition.nutrition(r).map { "\(Int($0.kcal)) kcal" }].compactMap { $0 }.joined(separator: " · "))
                        .foregroundColor(Theme.secondary)
                    if let src = r.source, let host = URL(string: src)?.host {
                        Label(host.replacingOccurrences(of: "www.", with: ""), systemImage: "link").font(.caption).foregroundColor(Theme.secondary)
                    }
                    HStack(spacing: 10) {
                        StarRating(value: m.rating) { kitchen.setRating(r.id, $0) }
                        if let c = cookedText(m) { Text(c).font(.caption).foregroundColor(Theme.secondary) }
                    }
                }
            }
            if session.recipe?.id == r.id {
                // Läuft gerade: Hinweis mit Abbrechen
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill").foregroundColor(Theme.accent)
                    Text("Wird gerade gekocht · \(session.stepText)").font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Abbrechen", role: .destructive) { confirmCancel = true }
                        .font(.subheadline.weight(.semibold)).buttonStyle(.borderless)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.1)))
            }
            HStack(spacing: 10) {
                SoftButton(title: session.recipe?.id == r.id ? "Weiterkochen" : "Kochen", symbol: "play.fill", primary: true) {
                    if session.recipe == nil || session.recipe?.id == r.id { session.start(r, portions: portions) }
                    else { replaceCooking = true }
                }
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
                PortionControl(value: $portions)
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
        let factor = Double(portions) / Double(r.baseServings)
        return VStack(alignment: .leading, spacing: 10) {
            Text("ZUBEREITUNG").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(r.steps.enumerated()), id: \.offset) { i, s in
                    if i > 0 { Divider() }
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)").font(.headline).foregroundColor(.white)
                            .frame(width: 28, height: 28).background(Circle().fill(Theme.accent))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(s.text).fixedSize(horizontal: false, vertical: true)
                            // Was dieser Schritt braucht – mit Mengen für die gewählten Portionen
                            let used = StepIngredients.find(r, step: i)
                            if !used.isEmpty {
                                Text(used.map { StepIngredients.line($0, factor) }.joined(separator: " · "))
                                    .font(.footnote).foregroundColor(Theme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack(spacing: 8) {
                                if let m = s.minutes {
                                    Button { timers.start("\(r.title) · Schritt \(i + 1)", minutes: m, source: r.title, icon: r.icon) } label: {
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

    /// Nährwerte pro Portion: Kalorien groß, darunter Eiweiß, Kohlenhydrate, Fett als Balken und Liste
    @ViewBuilder
    private func nutritionCard(_ r: Recipe) -> some View {
        if let n = nutrition.nutrition(r) {
            let sh = n.shares
            VStack(alignment: .leading, spacing: 10) {
                Text("NÄHRWERTE · PRO PORTION").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(n.kcal))").font(.system(size: 34, weight: .bold).monospacedDigit())
                        Text("kcal").font(.headline).foregroundColor(Theme.secondary)
                        Spacer(minLength: 0)
                        Text("ca.").font(.subheadline).foregroundColor(Theme.secondary)
                    }
                    // Energie-Anteile
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            Rectangle().fill(NutritionColors.protein).frame(width: max(0, geo.size.width * sh.p - 2))
                            Rectangle().fill(NutritionColors.carbs).frame(width: max(0, geo.size.width * sh.kh - 2))
                            Rectangle().fill(NutritionColors.fat)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)
                    .accessibilityHidden(true)
                    VStack(spacing: 0) {
                        nutritionRow("Eiweiß", n.p, NutritionColors.protein)
                        Divider()
                        nutritionRow("Kohlenhydrate", n.kh, NutritionColors.carbs)
                        nutritionRow("davon Zucker", n.z, nil).padding(.leading, 18)
                        Divider()
                        nutritionRow("Fett", n.f, NutritionColors.fat)
                        Divider()
                        nutritionRow("Ballaststoffe", n.bs, nil)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                Text("Richtwerte, aus den Zutaten berechnet – ohne Beilagen „zum Servieren“."
                     + (portions > 1 ? " Für \(portions) Portionen: \(Int(n.kcal) * portions) kcal." : ""))
                    .font(.caption).foregroundColor(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func nutritionRow(_ title: String, _ grams: Double, _ color: Color?) -> some View {
        HStack(spacing: 8) {
            if let c = color { Circle().fill(c).frame(width: 9, height: 9) }
            Text(title).foregroundColor(color == nil && title.hasPrefix("davon") ? Theme.secondary : .primary)
            Spacer(minLength: 8)
            Text("\(Int(grams)) g").font(.body.monospacedDigit().weight(.semibold))
        }
        .font(title.hasPrefix("davon") ? .subheadline : .body)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
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
    @ObservedObject private var session = CookSession.shared
    private var page: Int {
        get { session.page }
        nonmutating set { session.page = newValue }
    }
    @State private var showIngredients = false
    @State private var confirmCancel = false
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
                timers.start("\(recipe.title) · Schritt \(page + 1)", minutes: m, source: recipe.title, icon: recipe.icon)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Kopf: Schließen, Fortschritt, Zutaten
            HStack {
                // Minimieren: Kochen läuft als Kapsel unten weiter
                Button { session.minimize() } label: {
                    Image(systemName: "chevron.down").font(.headline).frame(width: 44, height: 44)
                        .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                }
                .accessibilityLabel("Kochansicht verlassen")
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
                // Mehr: minimieren oder abbrechen (mit Rückfrage)
                Menu {
                    Button { session.minimize() } label: { Label("Minimieren", systemImage: "chevron.down") }
                    Button(role: .destructive) { afterMenu { confirmCancel = true } } label: { Label("Kochen abbrechen", systemImage: "xmark.circle") }
                } label: {
                    Image(systemName: "ellipsis").font(.headline).foregroundColor(.primary).frame(width: 44, height: 44)
                        .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                }
                .accessibilityLabel("Mehr")
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

            // Breit (iPad): rechts alle Schritte – vorherige abgehakt, aktueller markiert, nächste darunter.
            // Schmal (iPhone): „Davor“ und „Als Nächstes“ direkt am Schritt.
            GeometryReader { g in
                let wide = g.size.width >= 700
                HStack(alignment: .top, spacing: 0) {
                    TabView(selection: $session.page) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, s in
                            stepPage(i, s, wide: wide).tag(i)
                        }
                        donePage.tag(recipe.steps.count)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    if wide {
                        stepList.frame(width: min(340, g.size.width * 0.34)).padding(.trailing, 16).padding(.vertical, 12)
                    }
                }
            }

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
        .cancelCookingAlert($confirmCancel)
        .overlay(TimerAlarmOverlay())
    }

    private func stepPage(_ i: Int, _ s: Recipe.Step, wide: Bool) -> some View {
        let needed = StepIngredients.find(recipe, step: i)
        let factor = Double(portions) / Double(recipe.baseServings)
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !wide && i > 0 {
                    Text("Davor: " + recipe.steps[i - 1].text).font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
                }
                Text(s.text).font(.system(size: 30, weight: .medium)).lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                // Mengen für diesen Schritt – passend zur gewählten Portionenzahl
                if !needed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DAFÜR · \(portions) \(portions == 1 ? "PORTION" : "PORTIONEN")")
                            .font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                        ForEach(Array(needed.enumerated()), id: \.offset) { _, ing in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(Amount.scale(ing.amount, factor)).font(.title3.weight(.semibold).monospacedDigit())
                                    .foregroundColor(Theme.accent).frame(minWidth: 90, alignment: .leading)
                                Text(ing.name).font(.title3)
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                }
                if let m = s.minutes {
                    let running = timers.timers.contains { $0.name.hasSuffix("Schritt \(i + 1)") }
                    Button { timers.start("\(recipe.title) · Schritt \(i + 1)", minutes: m, source: recipe.title, icon: recipe.icon) } label: {
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
                if !wide && i + 1 < recipe.steps.count {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ALS NÄCHSTES").font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                        Text(recipe.steps[i + 1].text).font(.body).foregroundColor(Theme.secondary).lineLimit(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                }
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    /// Alle Schritte an der Seite: vorherige abgehakt, aktueller hervorgehoben; antippen springt hin
    private var stepList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SCHRITTE").font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 4)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, s in
                        Button { withAnimation { page = i } } label: { stepRow(i, s) }
                            .buttonStyle(.plain)
                            .id(i)
                    }
                }
                .padding(.bottom, 12)
            }
            .onAppear { proxy.scrollTo(min(page, recipe.steps.count - 1), anchor: .center) }
            .onChange(of: page) { p in withAnimation { proxy.scrollTo(min(p, recipe.steps.count - 1), anchor: .center) } }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
    }

    private func stepRow(_ i: Int, _ s: Recipe.Step) -> some View {
        let done = i < page, now = i == page
        return HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(now ? Theme.accent : done ? Color(UIColor.tertiarySystemFill) : Color.clear)
                Circle().stroke(now || done ? Color.clear : Theme.secondary.opacity(0.4), lineWidth: 1.5)
                if done { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundColor(Theme.secondary) }
                else { Text("\(i + 1)").font(.caption.weight(.bold)).foregroundColor(now ? .white : Theme.secondary) }
            }
            .frame(width: 26, height: 26)
            Text(s.text).font(.subheadline.weight(now ? .semibold : .regular))
                .foregroundColor(done ? Theme.secondary : .primary)
                .lineLimit(now ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(now ? Theme.accent.opacity(0.1) : Color.clear))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }

    private var donePage: some View {
        VStack(spacing: 20) {
            Text(recipe.icon).font(.system(size: 90))
            Text("Guten Appetit!").font(.system(size: 34, weight: .bold))
            Text("Wie war's?").foregroundColor(Theme.secondary)
            StarRating(value: kitchen.metaFor(recipe.id).rating, size: 34) { kitchen.setRating(recipe.id, $0) }
            Button { kitchen.toggleFavorite(recipe.id) } label: {
                Label(kitchen.isFavorite(recipe.id) ? "In deinen Favoriten" : "Zu Favoriten",
                      systemImage: kitchen.isFavorite(recipe.id) ? "heart.fill" : "heart")
                    .font(.headline).foregroundColor(Theme.accent)
                    .padding(.horizontal, 18).frame(minHeight: 44)
                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            SoftButton(title: "Gekocht – fertig", symbol: "checkmark", primary: true) {
                kitchen.markCooked(recipe.id); session.end()
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
    @State private var dicing = false

    private var days: [Date] {
        (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date()))! }
    }

    var body: some View {
        List {
            Section {
                Button { dicing = true } label: {
                    Label("Woche würfeln", systemImage: "die.face.5").font(.headline)
                }
                Button {
                    Task {
                        let n = await kitchen.shoppingFromPlan()
                        message = n == 0 ? "Alles da – für die Woche fehlt nichts." : "\(n) Zutaten auf die Einkaufsliste gesetzt."
                    }
                } label: {
                    Label("Einkaufsliste für die Woche erstellen", systemImage: "cart.badge.plus").font(.headline)
                }
            } footer: {
                Text("Würfeln füllt die freien Tage mit passenden Hauptgerichten – mit Abwechslung, unter der Woche schnell. "
                     + "Die Einkaufsliste nimmt alle geplanten Rezepte der nächsten 7 Tage; was im Vorrat ist oder schon auf der Liste steht, kommt nicht dazu.")
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
                                        Text("\(e.portions) Portionen" + (s.time.map { " · " + $0 } ?? "") + (s.kcal.map { " · \($0) kcal" } ?? ""))
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
                                Menu {
                                    ForEach(days.filter { KitchenStore.day.string(from: $0) != e.day }, id: \.self) { t in
                                        Button(Fmt.dayLabel(t)) { withAnimation { kitchen.movePlan(e, to: t) } }
                                    }
                                } label: { Label("Auf anderen Tag", systemImage: "calendar") }
                                Button(role: .destructive) { kitchen.removeFromPlan(e) } label: { Label("Entfernen", systemImage: "trash") }
                            }
                        }
                    }
                    Button { picking = d } label: { Label("Rezept hinzufügen", systemImage: "plus") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $dicing) { WeekDiceSheet(days: days) }
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

// MARK: Hinzufügen (Einkauf und Vorrat)

/// Plus vor dem Eingabefeld – antippbar, grau solange nichts eingetippt ist
struct AddButton: View {
    let enabled: Bool
    let action: () -> Void
    var focus: (() -> Void)? = nil      // leeres Feld: Plus öffnet die Tastatur statt nichts zu tun
    var body: some View {
        Button { enabled ? action() : focus?() } label: {
            Image(systemName: "plus.circle.fill").font(.title2)
                .foregroundColor(enabled ? Theme.accent : Color(UIColor.tertiaryLabel))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .padding(.leading, -8)
        .accessibilityLabel("Hinzufügen")
    }
}

/// Minus am rechten Zeilenende: entfernt sofort, gut mit dem Daumen erreichbar
struct RemoveButton: View {
    let name: String
    let action: () -> Void
    var body: some View {
        Button { withAnimation { action() } } label: {
            Image(systemName: "minus.circle.fill").font(.title3).foregroundColor(Theme.secondary)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .padding(.trailing, -10)
        .accessibilityLabel("\(name) entfernen")
    }
}

/// Deutlicher Knopf rechts im Eingabefeld, sobald etwas eingetippt ist
struct AddPill: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Hinzufügen").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                .padding(.horizontal, 14).frame(minHeight: 36)
                .background(Capsule().fill(Theme.accent))
                .contentShape(Capsule())
        }
        .buttonStyle(.borderless)
        .transition(.opacity)
    }
}

/// Zeile unter dem Eingabefeld: „„Eier" hinzufügen · in Kühlschrank"
struct AddRow: View {
    let text: String
    let target: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.turn.down.left").font(.subheadline.weight(.semibold))
                Text("„\(text)“ hinzufügen").fontWeight(.semibold).lineLimit(1)
                Spacer(minLength: 8)
                Text(target).foregroundColor(Theme.secondary).lineLimit(1)
            }
            .foregroundColor(Theme.accent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .transition(.opacity)
    }
}

// MARK: Einkauf

struct ShopTab: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var newItem = ""
    @State private var siri = false
    @FocusState private var typing: Bool

    private var query: String { newItem.trimmingCharacters(in: .whitespaces) }
    private func add() { add(query) }
    private func add(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        withAnimation { kitchen.add("shop", name: n) }
        ShopSuggest.remember(n)
        newItem = ""; typing = true          // Tastatur bleibt offen für den nächsten Artikel
    }

    var body: some View {
        let open = kitchen.shop.filter { !$0.done }
        let done = kitchen.shop.filter { $0.done }
        let onList = Set(open.map { KitchenStore.key($0.name) })
        List {
            Section {
                HStack {
                    AddButton(enabled: !query.isEmpty, action: add, focus: { typing = true })
                    TextField("Artikel hinzufügen, z. B. Milch", text: $newItem)
                        .focused($typing).submitLabel(.done)
                        .onSubmit(add)
                        .disableAutocorrection(true)
                    if !query.isEmpty { AddPill(action: add) }
                }
                // Beim Tippen: passende Vorschläge zum direkten Hinzufügen
                SuggestRows(query: query, extra: kitchen.pantry.map(\.name) + kitchen.shop.map(\.name) + Array(kitchen.aliases.values),
                            taken: onList, takenText: "steht schon drauf") { add($0) }
            }
            Section(header: Text(open.isEmpty ? "Alles eingekauft" : "Noch zu kaufen · \(open.count)")) {
                ForEach(open) { ShopRow(item: $0) }
            }
            if !done.isEmpty {
                Section(header: Text("Eingekauft"), footer: Text("Abgehakte Artikel stehen automatisch im Vorrat. Zurückhaken nimmt sie dort wieder heraus.")) {
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

/// Vorschlagszeilen unter einem Eingabefeld (Einkauf, Vorrat)
struct SuggestRows: View {
    let query: String
    let extra: [String]
    let taken: Set<String>          // KitchenStore.key der Einträge, die schon da sind
    let takenText: String
    let onPick: (String) -> Void

    var body: some View {
        ForEach(ShopSuggest.find(query, extra: extra), id: \.name) { h in
            let already = taken.contains(KitchenStore.key(h.name))
            Button { if !already { onPick(h.name) } } label: {
                HStack(spacing: 12) {
                    Image(systemName: already ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title3).foregroundColor(already ? Theme.secondary : Theme.accent)
                        .frame(width: 28)
                    ShopSuggest.highlighted(h.name, query)
                        .foregroundColor(already ? Theme.secondary : .primary)
                    Spacer(minLength: 8)
                    Text(already ? takenText : h.label).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                }
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(already)
            .accessibilityLabel(already ? "\(h.name): \(takenText)" : "\(h.name) hinzufügen")
        }
    }
}

/// Vorschläge beim Tippen in der Einkaufsliste: Lebensmittel-Katalog, Haushalt/Drogerie,
/// zuletzt Gekauftes und was im Vorrat steht. Wortanfang zählt mehr als „irgendwo drin“.
enum ShopSuggest {
    struct Hit { let name: String; let label: String }

    static let household: [String] = [
        "Spülmaschinentabs", "Spülmittel", "Klarspüler", "Spülmaschinensalz", "Waschmittel", "Weichspüler", "Toilettenpapier",
        "Küchenrolle", "Taschentücher", "Müllbeutel", "Alufolie", "Backpapier", "Frischhaltefolie", "Gefrierbeutel",
        "Schwämme", "Putzmittel", "Glasreiniger", "WC-Reiniger", "Entkalker", "Batterien", "Glühbirne", "Kerzen",
        "Zahnpasta", "Zahnbürste", "Zahnseide", "Duschgel", "Shampoo", "Spülung", "Deo", "Seife", "Handcreme",
        "Rasierer", "Wattepads", "Wattestäbchen", "Sonnencreme", "Pflaster", "Kaffee", "Kaffeebohnen", "Tee",
        "Mineralwasser", "Sprudel", "Saft", "Bier", "Wein", "Chips", "Gummibärchen", "Müsli", "Cornflakes",
        "Marmelade", "Nutella", "Brot", "Toast", "Brötchen",
    ]

    private static let catalog: [(String, String)] = {
        var out: [(String, String)] = []
        for c in FoodCatalog.categories {
            for g in c.groups { for n in [g.name] + g.sorts { out.append((n, c.name)) } }
        }
        return out + household.map { ($0, "Haushalt & Co.") } + FoodNames.basics.map { ($0, "") }
    }()

    private static let historyKey = "shop.history"
    static func remember(_ name: String) {
        var h = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        h.removeAll { $0.lowercased() == name.lowercased() }
        h.insert(name, at: 0)
        UserDefaults.standard.set(Array(h.prefix(150)), forKey: historyKey)
    }

    static func find(_ q: String, extra: [String], limit: Int = 6) -> [Hit] {
        let query = q.lowercased()
        guard query.count >= 2 else { return [] }
        let history = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        var pool: [(String, String, Int)] = []          // Name, Hinweis, Bonus
        pool += history.map { ($0, "zuletzt gekauft", 30) }
        pool += extra.map { ($0, "", 20) }
        pool += catalog.map { ($0.0, $0.1, 0) }
        var seen = Set<String>(), scored: [(Hit, Int)] = []
        for (name, label, bonus) in pool {
            let k = name.lowercased()
            guard !k.isEmpty, !seen.contains(k) else { continue }
            var score: Int
            if k == query { score = 300 }
            else if k.hasPrefix(query) { score = 200 }
            else if k.split(whereSeparator: { $0 == " " || $0 == "-" }).contains(where: { $0.hasPrefix(query) }) { score = 150 }
            else if k.contains(query) { score = 80 }
            else { continue }
            seen.insert(k)
            let hint = label.isEmpty ? (FoodCatalog.ident(name).map { FoodCatalog.categories[$0.cat].name } ?? "") : label
            scored.append((Hit(name: name, label: hint), score + bonus - min(k.count, 30)))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    /// Getippter Teil fett hervorgehoben
    static func highlighted(_ name: String, _ q: String) -> Text {
        guard let r = name.range(of: q, options: .caseInsensitive), !q.isEmpty else { return Text(name) }
        return Text(String(name[..<r.lowerBound])) + Text(String(name[r])).bold() + Text(String(name[r.upperBound...]))
    }
}

struct ShopRow: View {
    let item: KitchenItem
    var compact = false
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var editing = false

    private var nameLabel: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(compact ? .subheadline : .body).strikethrough(item.done).foregroundColor(item.done ? Theme.secondary : .primary)
                    .lineLimit(1)
                let sub = [item.amount, item.recipe].filter { !$0.isEmpty && !$0.hasPrefix("shop:") }.joined(separator: " · ")
                if !sub.isEmpty && !compact { Text(sub).font(.caption).foregroundColor(Theme.secondary).lineLimit(1) }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { withAnimation { kitchen.toggle(item) } } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 20 : 24))
                    .foregroundColor(item.done ? .green : Color(UIColor.tertiaryLabel))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.done ? "Erledigt" : "Abhaken")
            // Antippen des Namens öffnet die Bearbeitung (Name, Menge) – nur in der Küche, nicht in der kleinen Kachel
            if compact { nameLabel }
            else { Button { editing = true } label: { nameLabel }.buttonStyle(.borderless) }
            if compact && !item.amount.isEmpty { Text(item.amount).font(.caption).foregroundColor(Theme.secondary) }
            if !compact { RemoveButton(name: item.name) { kitchen.delete(item) } }
        }
        .padding(.vertical, compact ? 0 : 2)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { kitchen.delete(item) } label: { Label("Löschen", systemImage: "trash") }
        }
        .sheet(isPresented: $editing) { ShopEditSheet(item: item) }
    }
}

/// Artikel der Einkaufsliste bearbeiten: Name und Menge.
struct ShopEditSheet: View {
    @State var item: KitchenItem
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $item.name)
                TextField("Menge, z. B. 500 g oder 2 Stück", text: $item.amount)
                Section {
                    Button(role: .destructive) { kitchen.delete(item); dismiss() } label: { Label("Von der Liste löschen", systemImage: "trash") }
                }
            }
            .navigationTitle("Artikel").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        item.name = item.name.trimmingCharacters(in: .whitespaces)
                        item.amount = item.amount.trimmingCharacters(in: .whitespaces)
                        kitchen.update(item); dismiss()
                    }
                    .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Vorrat

struct PantryTab: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var newItem = ""
    @State private var place = "Vorrat"
    @State private var editing: KitchenItem?
    @State private var scanning = false
    @AppStorage("hubert.pantry.blocks") private var showBlocks = false
    @FocusState private var typing: Bool

    private var query: String { newItem.trimmingCharacters(in: .whitespaces) }
    private func add() {
        guard !query.isEmpty else { return }
        withAnimation { kitchen.add("pantry", name: query, place: place) }
        newItem = ""; typing = true          // Tastatur bleibt offen für das nächste
    }
    /// Vorschlag übernehmen: bekannte Lebensmittel landen an ihrem üblichen Ort (Käse → Kühlschrank)
    private func pick(_ name: String) {
        let known = FoodCatalog.ident(name) != nil
        withAnimation { kitchen.add("pantry", name: name, place: known ? FoodCatalog.place(for: name) : place) }
        newItem = ""; typing = true
    }

    var body: some View {
        List {
            Section {
                Button { scanning = true } label: {
                    Label("Barcode oder Kassenzettel scannen", systemImage: "barcode.viewfinder").font(.headline)
                }
                HStack {
                    AddButton(enabled: !query.isEmpty, action: add, focus: { typing = true })
                    TextField("Hinzufügen, z. B. Reis", text: $newItem)
                        .focused($typing).submitLabel(.done)
                        .onSubmit(add)
                    Picker("Ort", selection: $place) { ForEach(KitchenStore.places, id: \.self) { Text($0) } }
                        .pickerStyle(.menu).labelsHidden()
                }
                // Sobald etwas eingetippt ist: deutliche Zeile zum Hinzufügen (Enter geht weiterhin)
                if !query.isEmpty { AddRow(text: query, target: place, action: add) }
                // Passende Vorschläge zum direkten Übernehmen
                SuggestRows(query: query, extra: kitchen.shop.map(\.name) + Array(kitchen.aliases.values),
                            taken: Set(kitchen.pantry.map { KitchenStore.key($0.name) }), takenText: "schon im Vorrat") { pick($0) }
            }
            Section {
                DisclosureGroup(isExpanded: $showBlocks.animation(.easeOut(duration: 0.2))) {
                    PantryBlocks()
                } label: {
                    Label("Schnell hinzufügen", systemImage: "square.grid.2x2").font(.headline)
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
        HStack(spacing: 4) {
            Button { editing = it } label: {
                HStack {
                    Text(it.name).foregroundColor(.primary)
                    Spacer()
                    if let d = it.daysLeft {
                        Text(d < 0 ? "abgelaufen" : d == 0 ? "heute" : d == 1 ? "morgen" : "noch \(d) Tage")
                            .font(.subheadline).foregroundColor(d <= 1 ? .red : d <= 3 ? .orange : Theme.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            // Minus rechts: sofort raus aus dem Vorrat, ohne Rückfrage
            RemoveButton(name: it.name) { kitchen.delete(it) }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { kitchen.delete(it) } label: { Label("Löschen", systemImage: "trash") }
            Button { kitchen.add("shop", name: it.name) } label: { Label("Einkaufen", systemImage: "cart.badge.plus") }.tint(Theme.accent)
        }
        // Rezepte mit dieser Zutat: nach rechts wischen (iPhone) oder gedrückt halten (überall)
        .swipeActions(edge: .leading) {
            Button { RecipeJump.shared.show(it.name) } label: { Label("Rezepte", systemImage: "fork.knife") }.tint(.green)
        }
        .contextMenu {
            Button { RecipeJump.shared.show(it.name) } label: { Label("Rezepte mit \(it.name)", systemImage: "fork.knife") }
            Button { kitchen.add("shop", name: it.name) } label: { Label("Auf die Einkaufsliste", systemImage: "cart.badge.plus") }
            Button(role: .destructive) { kitchen.delete(it) } label: { Label("Löschen", systemImage: "trash") }
        }
    }
}

/// Vorgefertigte Bausteine: Kategorie wählen, antippen = in den Vorrat, nochmal antippen = wieder raus
struct PantryBlocks: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @AppStorage("hubert.pantry.category") private var category = ""
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

    private struct Block: Hashable { let name: String; let place: String; let main: Bool }
    private struct Part: Hashable { let title: String; let blocks: [Block] }

    /// Gruppen mit Sorten bekommen eine eigene Überschrift, einzelne Lebensmittel landen gesammelt unter „Weitere“
    private func parts(_ c: FoodCategory) -> [Part] {
        var out: [Part] = []
        if let general = c.also.first {
            out.append(Part(title: "", blocks: [Block(name: general, place: c.place, main: true)]))
        }
        var single: [Block] = []
        for g in c.groups {
            if g.sorts.isEmpty {
                single.append(Block(name: g.name, place: g.place, main: false))
            } else {
                out.append(Part(title: g.name, blocks: [Block(name: g.name, place: g.place, main: true)]
                                + g.sorts.map { Block(name: $0, place: g.place, main: false) }))
            }
        }
        if !single.isEmpty { out.append(Part(title: out.count > 1 ? "Weitere" : "", blocks: single)) }
        return out
    }

    var body: some View {
        let cats = FoodCatalog.categories
        let current = cats.first { $0.name == category } ?? cats[0]
        let have = Set(kitchen.pantry.map { KitchenStore.key($0.name) })
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cats, id: \.name) { c in
                        let on = c.name == current.name
                        Button { category = c.name } label: {
                            Text(c.name).font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14).frame(minHeight: 36)
                                .foregroundColor(on ? .white : .primary)
                                .background(Capsule().fill(on ? Theme.accent : Color(UIColor.tertiarySystemFill)))
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }
            ForEach(parts(current), id: \.self) { part in
                VStack(alignment: .leading, spacing: 8) {
                    if !part.title.isEmpty {
                        Text(part.title.uppercased()).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                    }
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(part.blocks, id: \.self) { b in chip(b, has: have.contains(KitchenStore.key(b.name))) }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func chip(_ b: Block, has: Bool) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if has { kitchen.removeFromPantry(named: b.name) } else { kitchen.add("pantry", name: b.name, place: b.place) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: has ? "checkmark" : "plus").font(.caption.weight(.bold))
                Text(b.name).font(b.main ? .subheadline.weight(.semibold) : .subheadline)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundColor(has ? Theme.accent : .primary)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(has ? Theme.accent.opacity(0.15) : Color(UIColor.tertiarySystemFill)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(has ? "\(b.name) aus dem Vorrat entfernen" : "\(b.name) in den Vorrat")
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

/// Kompakte Portionen-Auswahl: − 2 Portionen +
/// Warum kein Stepper: Der Stepper ist breit und ragte auf dem iPad in die Spalte daneben.
struct PortionControl: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...20

    var body: some View {
        HStack(spacing: 6) {
            step("minus", enabled: value > range.lowerBound) { value -= 1 }
                .accessibilityLabel("Eine Portion weniger")
            Text(value == 1 ? "1 Portion" : "\(value) Portionen")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
            step("plus", enabled: value < range.upperBound) { value += 1 }
                .accessibilityLabel("Eine Portion mehr")
        }
    }

    private func step(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.footnote.weight(.bold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: Nährwerte – Farben für Eiweiß, Kohlenhydrate, Fett

enum NutritionColors {
    static let protein = Color(red: 0.20, green: 0.55, blue: 0.95)
    static let carbs = Color(red: 1.00, green: 0.62, blue: 0.04)
    static let fat = Color(red: 0.95, green: 0.33, blue: 0.40)
}

// MARK: Zutaten je Schritt

/// Welche Zutaten ein Schritt braucht – aus dem Schritttext erkannt.
/// Erst genaue Treffer („Zwiebeln“ → Zwiebeln, „Brühe“ → Gemüsebrühe); nur wenn ein Wort keinen genauen
/// Treffer hat, auch lose („Öl“ → Olivenöl). So trifft „Zucker“ nicht zusätzlich „Puderzucker“.
enum StepIngredients {
    /// „200 g Couscous“ – Menge für die gewählten Portionen, Name ohne Zusatz („Zwiebel, in Ringen“ → „Zwiebel“)
    static func line(_ ing: Recipe.Ingredient, _ factor: Double) -> String {
        var n = ing.name
        while let r = n.range(of: #"\s*\([^)]*\)"#, options: .regularExpression) { n.removeSubrange(r) }
        n = String(n.split(separator: ",").first ?? Substring(n)).trimmingCharacters(in: .whitespaces)
        let a = Amount.scale(ing.amount, factor)
        return a.isEmpty ? n : a + " " + n
    }

    private static let stop: Set<String> = Set(("frisch frische frischer gehackt gehackte gemahlen gemahlener getrocknet getrocknete klein kleine "
        + "große groß rot rote roter gelb gelbe grün grüne weiß weiße schwarz schwarzer optional fein feine gewürfelt geschält ca etwas "
        + "zum braten für den die das und oder nach geschmack bio tk dose glas reif reife sehr geschmolzene braune brauner heller dunkle "
        + "zerlassen festkochende mehligkochende servieren kühlregal").split(separator: " ").map(String.init))

    private static func words(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter }.map(String.init)
    }
    private static func stem(_ w: String) -> String {
        for suf in ["innen", "en", "er", "n", "e", "s"] where w.hasSuffix(suf) && w.count - suf.count >= 4 {
            return String(w.dropLast(suf.count))
        }
        return w
    }
    private static func keys(_ name: String) -> [String] {
        var n = name
        while let r = n.range(of: #"\([^)]*\)"#, options: .regularExpression) { n.removeSubrange(r) }
        n = String(n.split(separator: ",").first ?? "")
        let w = words(n)
        var k = w.filter { $0.count >= 3 && !stop.contains($0) }
        if k.isEmpty { k = Array(w.suffix(1)) }
        // „Knoblauchzehen“ passt auch bei „Knoblauch“ im Schritt, „Lachsfilets“ bei „Lachs“
        for x in k {
            if let suf = suffixes.first(where: { x.hasSuffix($0) && x.count - $0.count >= 4 }) { k.append(String(x.dropLast(suf.count))) }
        }
        return k
    }
    private static let suffixes = ["zehen", "zehe", "stangen", "stange", "filets", "filet", "schoten", "schote", "knolle",
                                   "kapseln", "körner", "samen", "würfel"]
    private static func strong(_ k: String, _ w: String) -> Bool {
        w == k || stem(w) == stem(k) || (k.count >= 4 && w.hasSuffix(k))
    }
    private static func weak(_ k: String, _ w: String) -> Bool {
        let ks = stem(k)
        return (w.count >= 3 && k.hasSuffix(w) && w.count >= max(3, k.count / 3))
            || (w == "öl" && k.hasSuffix("öl"))
            || (ks.count >= 5 && w.hasPrefix(ks))
    }

    static func find(_ r: Recipe, step: Int) -> [Recipe.Ingredient] {
        guard r.steps.indices.contains(step) else { return [] }
        let ings = r.ingredients.filter { !$0.name.isEmpty }
        // Rezepte aus der Sammlung: vorberechnet (auch „Gemüse würfeln“ → welches Gemüse)
        if !r.isOwn, let use = r.steps[step].use {
            return use.filter { ings.indices.contains($0) }.map { ings[$0] }
        }
        let ik = ings.map { keys($0.name) }
        var out: [Int] = []
        for w in words(r.steps[step].text) where w.count >= 2 {
            var hit = ings.indices.filter { i in ik[i].contains { strong($0, w) } }
            if hit.isEmpty { hit = ings.indices.filter { i in ik[i].contains { weak($0, w) } } }
            for i in hit where !out.contains(i) { out.append(i) }
        }
        return out.map { ings[$0] }
    }
}
