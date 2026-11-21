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

    /// Startet (oder setzt fort, wenn es dasselbe Rezept ist) und öffnet den Kochmodus.
    func start(_ r: Recipe, portions p: Int) {
        if recipe?.id != r.id || portions != p {
            if recipe?.id != r.id { page = 0 }
            recipe = r
            portions = p
        }
        presented = true
    }

    func minimize() { withAnimation(.easeOut(duration: 0.2)) { presented = false } }
    func resume() { if recipe != nil { presented = true } }

    func end() {
        withAnimation(.easeOut(duration: 0.2)) {
            presented = false
            recipe = nil
        }
        page = 0
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
