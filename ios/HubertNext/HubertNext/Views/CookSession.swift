import SwiftUI
import Combine

/// Laufendes Kochen – bleibt erhalten, wenn man die Kochansicht verlässt.
/// Wie bei den Timern: unten erscheint eine Kapsel, Antippen öffnet den Kochmodus wieder beim selben Schritt.
final class CookSession: ObservableObject {
    static let shared = CookSession()

    @Published private(set) var recipe: Recipe?
    @Published private(set) var portions = 2
    @Published var page = 0
    @Published var presented = false

    /// Haushalt für den Live-Abgleich (nil = nur auf diesem Gerät)
    var household: String?
    private var lastSynced: (recipe: String, portions: Int, page: Int)?
    private var pushedAt = Date.distantPast   // eigene Änderung unterwegs → älteren Serverstand kurz ignorieren
    private var bag = Set<AnyCancellable>()

    init() {
        // Schritt geändert → kurz warten, dann an die anderen Geräte melden
        $page.dropFirst().removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.push() }
            .store(in: &bag)
    }

    /// Startet (oder setzt fort, wenn es dasselbe Rezept ist) und öffnet den Kochmodus.
    func start(_ r: Recipe, portions p: Int) {
        if recipe?.id != r.id || portions != p {
            if recipe?.id != r.id { page = 0 }
            recipe = r
            portions = p
        }
        presented = true
        push()
    }

    func minimize() { withAnimation(.easeOut(duration: 0.2)) { presented = false } }
    func resume() { if recipe != nil { presented = true } }

    /// Beenden – `local` = kam vom Server (anderes Gerät hat beendet), dann nichts zurückmelden
    func end(local: Bool = false) {
        withAnimation(.easeOut(duration: 0.2)) {
            presented = false
            recipe = nil
        }
        page = 0
        lastSynced = nil
        if !local, let h = household {
            pushedAt = Date()
            // Als beendet markieren statt löschen – das melden die anderen Geräte zuverlässig
            struct Off: Encodable { let active = false }
            Task { try? await SupabaseClient.shared.update("kitchen_cooking", ["household_id": "eq." + h], Off()) }
        }
    }

    // MARK: Live-Abgleich

    private func push() {
        guard let h = household, let r = recipe else { return }
        if let l = lastSynced, l.recipe == r.id, l.portions == portions, l.page == page { return }
        lastSynced = (r.id, portions, page)
        pushedAt = Date()
        let row = LiveCookingRow(household_id: h, recipe_id: r.id, portions: portions, page: page, device: Device.id)
        Task { try? await SupabaseClient.shared.upsert("kitchen_cooking", [row]) }
    }

    /// Stand vom Server übernehmen (nil = niemand kocht gerade)
    func apply(remote row: LiveCookingRow?) async {
        if Date().timeIntervalSince(pushedAt) < 4 { return }
        guard let row = row else {
            if recipe != nil, lastSynced != nil { end(local: true) }
            return
        }
        lastSynced = (row.recipe_id, row.portions, row.page)
        if recipe?.id != row.recipe_id {
            guard let r = await KitchenStore.shared.recipe(row.recipe_id) else { return }
            presented = false
            recipe = r
        }
        if portions != row.portions { portions = row.portions }
        if page != row.page { page = row.page }   // folgt dem anderen Gerät Schritt für Schritt
    }

    /// Laufende Timer, die aus diesem Rezept gestartet wurden
    var recipeTimers: [KitchenTimer] {
        guard let r = recipe else { return [] }
        return TimerCenter.shared.timers.filter { $0.source == r.title }
    }

    /// Abbrechen: Kochen beenden und die Timer dieses Rezepts stoppen (nicht als „gekocht“ zählen)
    func cancel() {
        recipeTimers.forEach { TimerCenter.shared.cancel($0) }
        end()
    }

    var stepText: String {
        guard let r = recipe else { return "" }
        return page < r.steps.count ? "Schritt \(page + 1) von \(r.steps.count)" : "Fertig"
    }
}

/// Kochmodus als Vollbild über der ganzen App – wird von RootView eingehängt.
struct CookModeHost: ViewModifier {
    @ObservedObject private var session = CookSession.shared
    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $session.presented) {
            if let r = session.recipe { CookModeView(recipe: r, portions: session.portions) }
        }
    }
}

/// Rückfrage vor dem Abbrechen – überall gleich (Kochmodus, Rezept, Insel unten)
struct CancelCookingAlert: ViewModifier {
    @Binding var isPresented: Bool
    @ObservedObject private var session = CookSession.shared

    func body(content: Content) -> some View {
        content.alert("Kochen abbrechen?", isPresented: $isPresented) {
            Button("Weiterkochen", role: .cancel) {}
            Button("Abbrechen", role: .destructive) { session.cancel() }
        } message: {
            let n = session.recipeTimers.count
            Text("Dein Fortschritt bei „\(session.recipe?.title ?? "")“ geht verloren."
                 + (n == 0 ? "" : n == 1 ? " Der laufende Timer wird gestoppt." : " \(n) laufende Timer werden gestoppt."))
        }
    }
}

extension View {
    func cancelCookingAlert(_ isPresented: Binding<Bool>) -> some View { modifier(CancelCookingAlert(isPresented: isPresented)) }
}
