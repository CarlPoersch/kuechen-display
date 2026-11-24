import SwiftUI

// ============================================================
// Küchen-Buckets:
//  - Küche (App): Rezepte, Woche, Einkauf, Vorrat, Airfryer
//  - Timer (App): mehrere Timer gleichzeitig
//  - Einkauf & Vorrat (Startseite): oben am Titel umschalten; abhaken, hinzufügen, entfernen
//  - Rezept des Tages (Startseite): jeden Tag ein anderes Rezept
// ============================================================
enum KitchenBuckets {
    static let kitchen = BucketKind(
        id: "kueche", name: "Küche", symbol: "fork.knife", tint: .orange, art: .tool,
        interests: ["haushalt"], blurb: "Rezepte, Kochmodus, Wochenplan, Einkauf, Vorrat – gemeinsam im Haushalt.",
        detail: { _ in AnyView(KitchenView()) },
        settings: { binding in AnyView(KitchenSettings(config: binding)) }
    )

    /// „Uhr“: Wecker und Timer (ID bleibt „timer“, damit bestehende App-Symbole bleiben)
    static let timer = BucketKind(
        id: "timer", name: "Uhr", symbol: "alarm.fill", tint: .teal, art: .tool,
        interests: ["haushalt"], blurb: "Wecker und Timer – Wecker klingeln auf allen Geräten, Timer mit Namen.",
        detail: { _ in AnyView(ClockView()) }
    )

    static let shopping = BucketKind(
        id: "einkauf", name: "Einkauf & Vorrat", symbol: "cart.fill", tint: .green, art: .glance,
        interests: ["haushalt"], blurb: "Einkaufsliste und Vorrat in einer Karte – oben am Titel umschalten, direkt abhaken, hinzufügen und entfernen.",
        glance: { inst, _ in AnyView(ShoppingGlance(bucketId: inst.id)) },
        // „Alle ›“ öffnet die Küche passend zur gewählten Ansicht
        detail: { inst in AnyView(KitchenView(tab: BucketModes.shared.mode(inst.id, default: "shop") == "pantry" ? .pantry : .shop)) },
        itemLinks: true,
        parent: "kueche",         // Widget der Küche
        modes: [BucketMode(id: "shop", name: "Einkauf", symbol: "cart.fill"),
                BucketMode(id: "pantry", name: "Vorrat", symbol: "archivebox.fill")]
    )

    static let recipeOfDay = BucketKind(
        id: "rezept-tag", name: "Rezept des Tages", symbol: "sparkles", tint: .orange, art: .glance,
        interests: ["haushalt"], blurb: "Jeden Tag ein Rezept – bevorzugt eins, das ihr länger nicht gekocht habt.",
        glance: { _, _ in AnyView(RecipeOfDayGlance()) },
        detail: { _ in AnyView(RecipeOfDayDetail()) },
        parent: "kueche",
        inCatalog: false          // steckt jetzt in der Küchen-App (Rezepte); bestehende Karten bleiben
    )
}

/// Einkauf oder Vorrat auf der Startseite – umgeschaltet über den Titel im Kartenkopf
struct ShoppingGlance: View {
    let bucketId: String
    @EnvironmentObject var app: AppStore
    @ObservedObject private var kitchen = KitchenStore.shared
    @ObservedObject private var modes = BucketModes.shared
    @Environment(\.glanceSpace) private var space
    @State private var newItem = ""

    private var pantryMode: Bool { modes.mode(bucketId, default: "shop") == "pantry" }

    /// Vorrat: was bald weg muss zuerst, dann alphabetisch
    private var pantrySorted: [KitchenItem] {
        kitchen.pantry.sorted { a, b in
            let da = a.daysLeft ?? 999, db = b.daysLeft ?? 999
            return da != db ? da < db : a.name.localizedCompare(b.name) == .orderedAscending
        }
    }

    private func add() {
        let n = newItem.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        if pantryMode {
            // bekannte Lebensmittel landen an ihrem üblichen Ort (Käse → Kühlschrank)
            let place = FoodCatalog.ident(n) != nil ? FoodCatalog.place(for: n) : "Vorrat"
            withAnimation { kitchen.add("pantry", name: n, place: place) }
        } else {
            withAnimation { kitchen.add("shop", name: n) }
        }
        newItem = ""
    }

    var body: some View {
        let canAdd = space.height > 110
        VStack(alignment: .leading, spacing: 0) {
            if pantryMode { pantryList(canAdd) } else { shopList(canAdd) }
            if canAdd {
                HStack {
                    let empty = newItem.trimmingCharacters(in: .whitespaces).isEmpty
                    Button(action: add) {
                        Image(systemName: "plus.circle.fill").foregroundColor(empty ? Color(UIColor.tertiaryLabel) : Theme.accent)
                    }
                    .buttonStyle(.borderless).disabled(empty)
                    .accessibilityLabel("Hinzufügen")
                    TextField(pantryMode ? "In den Vorrat" : "Hinzufügen", text: $newItem).submitLabel(.done)
                        .onSubmit(add)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
            }
        }
        .refreshing(id: app.household?.id ?? "", every: { 15 }) {
            await KitchenStore.shared.sync(household: app.household?.id)
        }
    }

    @ViewBuilder private func shopList(_ canAdd: Bool) -> some View {
        let open = kitchen.shop.filter { !$0.done }
        if open.isEmpty {
            Label("Alles eingekauft", systemImage: "checkmark.circle").foregroundColor(Theme.secondary).padding(.vertical, 6)
            Spacer(minLength: 0)
        } else {
            GlancePager(pages: Pages.split(open, height: space.height - (canAdd ? 52 : 0), row: 34)) { page in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(page.enumerated()), id: \.element.id) { i, it in
                        if i > 0 { Divider() }
                        ShopRow(item: it, compact: true).padding(.vertical, 6)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func pantryList(_ canAdd: Bool) -> some View {
        let list = pantrySorted
        if list.isEmpty {
            Label("Vorrat ist noch leer", systemImage: "archivebox").foregroundColor(Theme.secondary).padding(.vertical, 6)
            Spacer(minLength: 0)
        } else {
            GlancePager(pages: Pages.split(list, height: space.height - (canAdd ? 52 : 0), row: 38)) { page in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(page.enumerated()), id: \.element.id) { i, it in
                        if i > 0 { Divider() }
                        PantryGlanceRow(item: it)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Vorratszeile in der Karte: Name, Ort/Haltbarkeit, Minus rechts entfernt sofort
struct PantryGlanceRow: View {
    let item: KitchenItem
    @ObservedObject private var kitchen = KitchenStore.shared

    var body: some View {
        HStack(spacing: 8) {
            Text(item.name).font(.subheadline).lineLimit(1)
            Spacer(minLength: 4)
            if let d = item.daysLeft, d <= 3 {
                Text(d < 0 ? "abgelaufen" : d == 0 ? "heute" : d == 1 ? "morgen" : "noch \(d) Tage")
                    .font(.caption).foregroundColor(d <= 1 ? .red : .orange)
            } else if !item.place.isEmpty && item.place != "Vorrat" {
                Text(item.place).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
            }
            Button { withAnimation { kitchen.delete(item) } } label: {
                Image(systemName: "minus.circle.fill").font(.body).foregroundColor(Theme.secondary)
                    .frame(width: 38, height: 38).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .padding(.trailing, -8)
            .accessibilityLabel("\(item.name) entfernen")
        }
        .frame(height: 38)
    }
}

/// Rezept des Tages auf der Startseite
struct RecipeOfDayGlance: View {
    @EnvironmentObject var app: AppStore
    @ObservedObject private var kitchen = KitchenStore.shared
    @Environment(\.glanceSpace) private var space

    var body: some View {
        Group {
            if let r = kitchen.recipeOfTheDay() {
                let m = kitchen.metaFor(r.id)
                let big = space.height > 150
                HStack(alignment: .center, spacing: 14) {
                    Text(r.icon).font(.system(size: big ? 64 : 44))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(r.title).font(big ? .title3.weight(.semibold) : .headline).lineLimit(2)
                        Text([r.cuisine, r.time].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                        if big {
                            if let c = cookedText(m) { Text(c).font(.caption).foregroundColor(Theme.secondary) }
                            else { Text("Noch nie gekocht").font(.caption).foregroundColor(Theme.secondary) }
                            if r.airfryer == true { Label("Airfryer", systemImage: "flame.fill").font(.caption).foregroundColor(.orange) }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await KitchenStore.shared.loadRecipes()
            await KitchenStore.shared.sync(household: app.household?.id)
        }
    }
}

struct RecipeOfDayDetail: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    var body: some View {
        if let r = kitchen.recipeOfTheDay() { RecipeDetailView(id: r.id) }
        else { ProgressView().task { await KitchenStore.shared.loadRecipes() } }
    }
}

/// Einstellungen der Küche: Ernährung voreinstellen (gilt für Rezepte, Rezept des Tages, Zufall)
struct KitchenSettings: View {
    @Binding var config: [String: JSON]
    @AppStorage("hubert.diet.kitchen") private var diet = "Alle"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ERNÄHRUNG").font(.footnote).foregroundColor(Theme.secondary)
            Picker("Ernährung", selection: Binding(get: { diet }, set: { v in diet = v; config["diet"] = .string(v) })) {
                ForEach(RecipeFilter.diets, id: \.self) { Text($0 == "Alle" ? "Alles" : $0).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(diet == "Alle"
                 ? "Rezepte zeigen alles. Wählst du Vegetarisch oder Vegan, siehst du nur noch passende Rezepte – auf allen deinen Geräten."
                 : "Die Küche zeigt nur noch passende Rezepte (\(diet)). Für zwischendurch alles: in Rezepte beim Filter auf „Alle“ stellen.")
                .font(.footnote).foregroundColor(Theme.secondary)
        }
    }
}
