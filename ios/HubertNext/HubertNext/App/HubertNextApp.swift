import SwiftUI

@main
struct HubertNextApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                // Timer klingeln über allem; laufendes Kochen und laufende Timer als „Inseln“ unten
                .overlay(alignment: .bottom) {
                    ActivityBar().padding(.bottom, 12)
                }
                .modifier(CookModeHost())
                .overlay(TimerAlarmOverlay())
                .overlay(AlarmRingOverlay())
                .animation(.easeOut(duration: 0.2), value: AlarmCenter.shared.ringing != nil)
                .animation(.easeOut(duration: 0.2), value: TimerCenter.shared.ringing.count)
                .environmentObject(store)
                .task { await store.start() }
                // Rückweg aus der Spotify-App nach dem Anmelden/Verbinden
                .onOpenURL { SpotifyCenter.shared.handle($0) }
        }
        .onChange(of: scenePhase) { phase in
            // Display bleibt an, solange Hubert offen ist (Wand-iPad)
            UIApplication.shared.isIdleTimerDisabled = (phase == .active)
            if phase == .active, store.phase == .ready { Task { await store.reload() } }
            // Live-Abgleich (Timer, Kochen, Einkauf) nur im Vordergrund – beim Öffnen sofort nachziehen
            if phase == .active { LiveSync.shared.start(household: store.household?.id) }
            if phase == .background { LiveSync.shared.pause() }
            // Spotify: im Hintergrund Verbindung lösen (Musik läuft weiter), beim Öffnen leise neu verbinden
            if phase == .active { SpotifyCenter.shared.appBecameActive() }
            if phase == .background { SpotifyCenter.shared.appEnteredBackground() }
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
            .modifier(FocusHost())    // Fokus im Vollbild
            // Haushalt bekannt (Start, Beitritt, Wechsel) → Live-Abgleich starten
            .task(id: store.household?.id) { LiveSync.shared.start(household: store.household?.id) }
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
