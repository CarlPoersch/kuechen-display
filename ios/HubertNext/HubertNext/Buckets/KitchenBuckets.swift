import SwiftUI

// ============================================================
// Küchen-Buckets:
//  - Küche (App): Rezepte, Woche, Einkauf, Vorrat, Airfryer
//  - Timer (App): mehrere Timer gleichzeitig
//  - Einkauf (Startseite): offene Artikel, direkt abhaken oder hinzufügen
//  - Rezept des Tages (Startseite): jeden Tag ein anderes Rezept
// ============================================================
enum KitchenBuckets {
    static let kitchen = BucketKind(
        id: "kueche", name: "Küche", symbol: "fork.knife", tint: .orange, art: .tool,
        interests: ["haushalt"], blurb: "Rezepte, Kochmodus, Wochenplan, Einkauf, Vorrat – gemeinsam im Haushalt.",
        detail: { _ in AnyView(KitchenView()) },
        settings: { binding in AnyView(KitchenSettings(config: binding)) }
    )

    static let timer = BucketKind(
        id: "timer", name: "Timer", symbol: "timer", tint: .teal, art: .tool,
        interests: ["haushalt"], blurb: "Mehrere Timer gleichzeitig, mit Namen.",
        detail: { _ in AnyView(TimerToolView()) }
    )

    static let shopping = BucketKind(
        id: "einkauf", name: "Einkauf", symbol: "cart.fill", tint: .green, art: .glance,
        interests: ["haushalt"], blurb: "Die Einkaufsliste des Haushalts – abhaken und hinzufügen direkt auf der Startseite.",
        glance: { _, _ in AnyView(ShoppingGlance()) },
        detail: { _ in AnyView(KitchenView(tab: .shop)) },
        itemLinks: true,
        parent: "kueche"          // Widget der Küche
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

/// Einkaufsliste auf der Startseite
struct ShoppingGlance: View {
    @EnvironmentObject var app: AppStore
    @ObservedObject private var kitchen = KitchenStore.shared
    @Environment(\.glanceSpace) private var space
    @State private var newItem = ""

    var body: some View {
        let open = kitchen.shop.filter { !$0.done }
        let canAdd = space.height > 110
        VStack(alignment: .leading, spacing: 0) {
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
            if canAdd {
                HStack {
                    let empty = newItem.trimmingCharacters(in: .whitespaces).isEmpty
                    Button { kitchen.add("shop", name: newItem); newItem = "" } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(empty ? Color(UIColor.tertiaryLabel) : Theme.accent)
                    }
                    .buttonStyle(.borderless).disabled(empty)
                    .accessibilityLabel("Hinzufügen")
                    TextField("Hinzufügen", text: $newItem).submitLabel(.done)
                        .onSubmit { kitchen.add("shop", name: newItem); newItem = "" }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
            }
        }
        .refreshing(id: app.household?.id ?? "", every: { 15 }) {
            await KitchenStore.shared.sync(household: app.household?.id)
        }
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
