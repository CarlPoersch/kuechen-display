import SwiftUI

// ============================================================
// Küchen-Display – native Hülle für die Web-App.
//
// Die App zeigt nur die Seite von GitHub Pages im Vollbild.
// Warum so: Inhalte (Rezepte, Einkauf, Fahrten …) ändern sich weiter
// über GitHub, ohne die App neu zu bauen. Die native Hülle umgeht den
// iOS-15-Fehler, bei dem Home-Bildschirm-Web-Apps keine Tastatur zeigen,
// und hält das Display wach.
// ============================================================

/// Adresse der Web-App
let kuecheURL = URL(string: "https://carlpoersch.github.io/kuechen-display/")!

@main
struct KuecheApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WebView(url: kuecheURL)
                .ignoresSafeArea()          // bis an den Rand, wie im Vollbild-Modus
                .statusBar(hidden: true)    // keine Uhr/Akku-Leiste oben
        }
        .onChange(of: scenePhase) { phase in
            // Warum: Solange die App im Vordergrund ist, soll das Display nie
            // automatisch ausgehen – egal, was in den iPad-Einstellungen steht.
            UIApplication.shared.isIdleTimerDisabled = (phase == .active)
        }
    }
}
