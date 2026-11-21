import SwiftUI

@main
struct HubertNextApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                // Timer klingeln über allem; laufende Timer als Kapsel unten
                .overlay(alignment: .bottom) { RunningTimersPill() }
                .overlay(TimerAlarmOverlay())
                .animation(.easeOut(duration: 0.2), value: TimerCenter.shared.ringing.count)
                .environmentObject(store)
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
    @ObservedObject private var look = ThemeStore.shared

    var body: some View {
        content
            // Farbthema: Knöpfe, Schalter und Zurück-Pfeile (accentColor braucht iOS 15 für die Navigationsleiste)
            .tint(look.current.accent)
            .accentColor(look.current.accent)
    }

    @ViewBuilder private var content: some View {
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
