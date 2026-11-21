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

/// Kapsel „Wird gekocht“ unten – Antippen öffnet den Kochmodus, ✕ beendet nach Rückfrage.
struct CookingPill: View {
    @ObservedObject private var session = CookSession.shared
    @State private var confirmEnd = false

    var body: some View {
        if let r = session.recipe, !session.presented {
            HStack(spacing: 10) {
                Button { session.resume() } label: {
                    HStack(spacing: 8) {
                        Text(r.icon).font(.body)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(session.stepText).font(.caption).foregroundColor(Theme.secondary)
                        }
                        Image(systemName: "chevron.up").font(.caption.weight(.bold)).foregroundColor(Theme.accent)
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kochmodus für „\(r.title)“ öffnen, \(session.stepText)")
                Button { confirmEnd = true } label: {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundColor(Theme.secondary)
                        .frame(width: 26, height: 26).background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kochen beenden")
            }
            .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 7)
            .background(Capsule().fill(.regularMaterial))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .confirmationDialog("Kochen von „\(r.title)“ beenden?", isPresented: $confirmEnd, titleVisibility: .visible) {
                Button("Beenden", role: .destructive) { session.end() }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }
}
