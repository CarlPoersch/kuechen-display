import SwiftUI

@main
struct HubertNextApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
                .task { await store.start() }
        }
        .onChange(of: scenePhase) { phase in
            // Display bleibt an, solange Hubert offen ist (Wand-iPad)
            UIApplication.shared.isIdleTimerDisabled = (phase == .active)
            if phase == .active, store.phase == .ready { Task { await store.reload() } }
        }
    }
}

/// Zeigt je nach Zustand Anmeldung/Onboarding oder die Startseite
struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        switch store.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background.ignoresSafeArea())
        case .signedOut, .onboarding:
            OnboardingView()
        case .ready:
            HomeView()
        }
    }
}
