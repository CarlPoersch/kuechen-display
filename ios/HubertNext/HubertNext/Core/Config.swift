import SwiftUI

/// Feste Einstellungen der App.
/// Warum der Schlüssel hier stehen darf: Der "publishable key" ist für Apps gedacht.
/// Geschützt werden die Daten über die Anmeldung und die Zugriffsregeln (RLS) in Supabase.
enum Config {
    static let supabaseURL = URL(string: "https://jcnpfkyntdujgudewmzb.supabase.co")!
    static let supabaseKey = "sb_publishable_CYlA5db0qaRSHec7pMlk8w_2L39e_AV"

    /// Spotify: Client ID aus dem Spotify-Developer-Dashboard (developer.spotify.com/dashboard).
    /// Darf in der App stehen: Die Anmeldung läuft über PKCE, ein Client Secret gibt es in der App nicht.
    /// Im Dashboard eintragen: Redirect URI = spotifyRedirect, iOS-Bundle-ID = com.carlpoersch.HubertNext.
    static let spotifyClientID = "02c1ddd0336d4c86921f9c665ea24b51"
    static let spotifyRedirect = URL(string: "hubert-spotify://callback")!
}

/// Farben im Apple-Look. Systemfarben passen sich hell/dunkel automatisch an.
enum Theme {
    /// Akzentfarbe des gewählten Farbthemas (Einstellungen → Darstellung)
    static var accent: Color { ThemeStore.shared.current.accent }
    static let background = Color(UIColor.systemGroupedBackground)
    static let card = Color(UIColor.secondarySystemGroupedBackground)
    static let secondary = Color(UIColor.secondaryLabel)
    static let cardRadius: CGFloat = 22
}
