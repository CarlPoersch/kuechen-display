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
        detail: { _ in AnyView(KitchenView()) }
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
        itemLinks: true
    )

    static let recipeOfDay = BucketKind(
        id: "rezept-tag", name: "Rezept des Tages", symbol: "sparkles", tint: .orange, art: .glance,
        interests: ["haushalt"], blurb: "Jeden Tag ein Rezept – bevorzugt eins, das ihr länger nicht gekocht habt.",
        glance: { _, _ in AnyView(RecipeOfDayGlance()) },
        detail: { _ in AnyView(RecipeOfDayDetail()) }
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
        let rows = fitRows(space.height - (canAdd ? 44 : 0), row: 34, max: 12)
        VStack(alignment: .leading, spacing: 0) {
            if open.isEmpty {
                Label("Alles eingekauft", systemImage: "checkmark.circle").foregroundColor(Theme.secondary).padding(.vertical, 6)
            }
            ForEach(Array(open.prefix(rows).enumerated()), id: \.element.id) { i, it in
                if i > 0 { Divider() }
                ShopRow(item: it, compact: true).padding(.vertical, 6)
            }
            if open.count > rows {
                Text("+ \(open.count - rows) weitere").font(.caption).foregroundColor(Theme.secondary).padding(.top, 4)
            }
            Spacer(minLength: 0)
            if canAdd {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent)
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

/// Laufende Timer als kleine Kapsel unten – überall sichtbar.
/// Antippen öffnet die laufenden Timer (stoppen, pausieren, +1 Min.), ✕ stoppt den nächsten direkt.
struct RunningTimersPill: View {
    @ObservedObject private var center = TimerCenter.shared
    @State private var showAll = false

    var body: some View {
        if let t = center.timers.sorted(by: { $0.left < $1.left }).first {
            HStack(spacing: 10) {
                Button { showAll = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "timer").foregroundColor(Theme.accent)
                        Text(t.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(TimerCenter.format(t.left)).font(.subheadline.monospacedDigit().weight(.bold))
                        if center.timers.count > 1 { Text("+\(center.timers.count - 1)").font(.caption).foregroundColor(Theme.secondary) }
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Laufende Timer anzeigen")
                Button { center.cancel(t) } label: {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundColor(.red)
                        .frame(width: 26, height: 26).background(Circle().fill(Color.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Timer „\(t.name)“ stoppen")
            }
            .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
            .background(Capsule().fill(.regularMaterial))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .sheet(isPresented: $showAll) { RunningTimersSheet() }
        }
    }
}

/// Alle laufenden Timer mit Stopp, Pause und +1 Min.
struct RunningTimersSheet: View {
    @ObservedObject private var center = TimerCenter.shared
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List {
                if center.timers.isEmpty { Text("Kein Timer läuft").foregroundColor(Theme.secondary) }
                ForEach(center.timers) { TimerRow(timer: $0).padding(.vertical, 4) }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Laufende Timer").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .onChange(of: center.timers.count) { n in if n == 0 { dismiss() } }
        }
        .navigationViewStyle(.stack)
    }
}
