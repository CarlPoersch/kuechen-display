import SwiftUI
import Combine
#if canImport(SpotifyiOS)
import SpotifyiOS
#endif

// ============================================================
// Spotify: Hubert steuert die Spotify-App auf diesem Gerät.
// - Anmeldung und Steuerung über das Spotify iOS SDK (App Remote, PKCE – kein Server nötig)
// - Bibliothek (Playlists, Lieblingssongs, zuletzt gehört) über die Spotify Web API
// Die Musik selbst spielt immer die Spotify-App. Zum Verbinden wechselt Hubert kurz
// zu Spotify und kommt automatisch zurück.
// Die Anmeldung gilt pro Gerät (Schlüsselbund), nicht für den ganzen Haushalt.
// Einrichtung: Config.spotifyClientID + Paket github.com/spotify/ios-sdk (Produkt „SpotifyiOS“).
// ============================================================

/// Was gerade läuft
struct SpotifyNowPlaying: Equatable {
    var uri: String
    var title: String
    var artist: String
    var album: String
    var context: String
    var paused: Bool
    var shuffle: Bool
    var canNext: Bool
    var canPrevious: Bool
}

/// Ein Eintrag der Bibliothek (Playlist oder Titel)
struct SpotifyItem: Identifiable, Hashable {
    let uri: String
    let title: String
    let subtitle: String
    let image: URL?
    var id: String { uri }
}

final class SpotifyCenter: NSObject, ObservableObject {
    static let shared = SpotifyCenter()

    enum Phase: Equatable {
        case unavailable(String)   // nicht eingerichtet (Client ID oder Paket fehlt)
        case signedOut             // noch nie angemeldet
        case disconnected          // angemeldet, aber gerade nicht mit der Spotify-App verbunden
        case connecting
        case connected
        case failed(String)
    }

    @Published private(set) var phase: Phase = .signedOut
    @Published private(set) var now: SpotifyNowPlaying?
    @Published private(set) var cover: UIImage?
    @Published private(set) var playlists: [SpotifyItem] = []
    @Published private(set) var liked: [SpotifyItem] = []
    @Published private(set) var recent: [SpotifyItem] = []
    @Published private(set) var libraryLoading = false
    @Published private(set) var libraryError: String?

    private static let keychainService = "com.carlpoersch.HubertNext.spotify"
    private var userId: String?
    private var coverURI: String?
    private var retriedConnect = false
    private var quietAttempt = false
    private var tokenWaiters: [(String?) -> Void] = []

    /// Angemeldet (Zugang im Schlüsselbund), egal ob gerade verbunden
    var isSignedIn: Bool {
        #if canImport(SpotifyiOS)
        if case .unavailable = phase { return false }
        return sessionManager.session != nil
        #else
        return false
        #endif
    }

    #if canImport(SpotifyiOS)
    /// Rechte: App steuern + Bibliothek lesen
    private let scope: SPTScope = [.appRemoteControl, .playlistReadPrivate, .playlistReadCollaborative,
                                   .userLibraryRead, .userReadRecentlyPlayed]

    private lazy var configuration: SPTConfiguration = {
        let c = SPTConfiguration(clientID: Config.spotifyClientID, redirectURL: Config.spotifyRedirect)
        // Nicht nil, damit Spotify nach der Anmeldung spielt und die Verbindung sofort klappt
        // ("" = da weitermachen, wo man aufgehört hat)
        c.playURI = ""
        return c
    }()

    private lazy var sessionManager = SPTSessionManager(configuration: configuration, delegate: self)

    private lazy var appRemote: SPTAppRemote = {
        let r = SPTAppRemote(configuration: configuration, logLevel: .error)
        r.delegate = self
        return r
    }()
    #endif

    override private init() {
        super.init()
        #if canImport(SpotifyiOS)
        if Config.spotifyClientID.isEmpty {
            phase = .unavailable("Spotify ist noch nicht eingerichtet: Die Client ID fehlt.")
            return
        }
        if let data = Keychain.load(service: Self.keychainService),
           let session = try? NSKeyedUnarchiver.unarchivedObject(ofClass: SPTSession.self, from: data) {
            sessionManager.session = session
            phase = .disconnected
        }
        #else
        phase = .unavailable("Spotify ist noch nicht eingerichtet: Das Spotify-Paket fehlt im Projekt.")
        #endif
    }

    // MARK: Anmelden, verbinden, abmelden

    /// Öffnet Spotify zum Anmelden bzw. Verbinden und spielt `uri` ab ("" = weiter hören).
    /// Kommt automatisch zu Hubert zurück.
    func connect(playing uri: String = "") {
        #if canImport(SpotifyiOS)
        if case .unavailable = phase { return }
        guard sessionManager.isSpotifyAppInstalled else {
            phase = .failed("Installiere zuerst die Spotify-App aus dem App Store und melde dich dort an.")
            return
        }
        configuration.playURI = uri
        retriedConnect = false
        phase = .connecting
        sessionManager.initiateSession(with: scope, options: .default, campaign: nil)
        #endif
    }

    /// Leise verbinden, ohne zu Spotify zu wechseln (klappt, wenn Spotify im Hintergrund läuft)
    func reconnectQuietly() {
        #if canImport(SpotifyiOS)
        guard phase == .disconnected, !quietAttempt, let session = sessionManager.session else { return }
        if session.isExpired {
            withToken { [weak self] token in
                guard let self = self, token != nil else { return }
                self.reconnectQuietly()
            }
            return
        }
        quietAttempt = true
        appRemote.connectionParameters.accessToken = session.accessToken
        appRemote.connect()
        #endif
    }

    func signOut() {
        #if canImport(SpotifyiOS)
        if appRemote.isConnected { appRemote.disconnect() }
        sessionManager.session = nil
        #endif
        Keychain.save(nil, service: Self.keychainService)
        now = nil; cover = nil; coverURI = nil; userId = nil
        playlists = []; liked = []; recent = []; libraryError = nil
        if case .unavailable = phase { return }
        phase = .signedOut
    }

    /// Rückweg aus der Spotify-App (Redirect URI)
    func handle(_ url: URL) {
        #if canImport(SpotifyiOS)
        guard url.scheme == Config.spotifyRedirect.scheme else { return }
        _ = sessionManager.application(UIApplication.shared, open: url, options: [:])
        #endif
    }

    /// App kommt in den Vordergrund
    func appBecameActive() {
        reconnectQuietly()
    }

    /// App geht in den Hintergrund: Verbindung lösen (Spotify spielt weiter)
    func appEnteredBackground() {
        #if canImport(SpotifyiOS)
        guard phase == .connected else { return }
        appRemote.disconnect()
        phase = .disconnected
        #endif
    }

    // MARK: Steuern

    func togglePlay() {
        #if canImport(SpotifyiOS)
        guard let api = connectedPlayer() else { connect(); return }
        if now?.paused ?? true { api.resume(nil) } else { api.pause(nil) }
        #endif
    }

    func next() {
        #if canImport(SpotifyiOS)
        connectedPlayer()?.skip(toNext: nil)
        #endif
    }

    func previous() {
        #if canImport(SpotifyiOS)
        connectedPlayer()?.skip(toPrevious: nil)
        #endif
    }

    func toggleShuffle() {
        #if canImport(SpotifyiOS)
        guard let api = connectedPlayer(), let n = now else { return }
        api.setShuffle(!n.shuffle, callback: nil)
        #endif
    }

    /// Playlist, Album oder Titel abspielen. Ist Spotify nicht verbunden, öffnet Hubert Spotify kurz und spielt dann.
    func play(_ uri: String) {
        #if canImport(SpotifyiOS)
        guard let api = connectedPlayer() else { connect(playing: uri); return }
        api.play(uri) { [weak self] _, error in
            if error != nil { DispatchQueue.main.async { self?.connect(playing: uri) } }
        }
        #endif
    }

    /// Lieblingssongs als Ganzes abspielen
    func playLiked() {
        if let id = userId { play("spotify:user:\(id):collection") }
        else if let first = liked.first { play(first.uri) }
    }

    #if canImport(SpotifyiOS)
    private func connectedPlayer() -> SPTAppRemotePlayerAPI? {
        guard appRemote.isConnected else { return nil }
        return appRemote.playerAPI
    }
    #endif

    // MARK: Bibliothek (Web API)

    func loadLibrary() async {
        guard isSignedIn, !libraryLoading else { return }
        libraryLoading = true
        defer { libraryLoading = false }
        do {
            // Playlists sind Pflicht (zeigen auch, ob das Konto freigegeben ist);
            // Lieblingssongs und Verlauf dürfen einzeln fehlen, falls Spotify einen Endpunkt sperrt
            let pj = try await get("me/playlists?limit=50")
            playlists = Self.items(pj).compactMap(Self.playlist)
            if userId == nil { userId = (try? await get("me"))?["id"] as? String }
            if let lj = try? await get("me/tracks?limit=50") {
                liked = Self.items(lj).compactMap { Self.track($0["track"]) }
            }
            if let rj = try? await get("me/player/recently-played?limit=30") {
                var seen = Set<String>()
                recent = Self.items(rj).compactMap { Self.track($0["track"]) }.filter { seen.insert($0.uri).inserted }
            }
            libraryError = nil
        } catch SpotifyError.forbidden {
            libraryError = "Dieses Spotify-Konto ist für Hubert noch nicht freigegeben (Spotify-Dashboard → User Management)."
        } catch SpotifyError.signedOut {
            libraryError = "Bitte neu mit Spotify verbinden."
        } catch {
            libraryError = "Deine Bibliothek ließ sich gerade nicht laden."
        }
    }

    private enum SpotifyError: Error { case signedOut, forbidden, http(Int) }

    private func get(_ path: String) async throws -> [String: Any] {
        guard let token = await freshToken() else { throw SpotifyError.signedOut }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/" + path)!)
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw SpotifyError.signedOut }
        if code == 403 { throw SpotifyError.forbidden }
        guard (200..<300).contains(code) else { throw SpotifyError.http(code) }
        if data.isEmpty { return [:] }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func freshToken() async -> String? {
        await withCheckedContinuation { cont in withToken { cont.resume(returning: $0) } }
    }

    /// Gültiger Zugangsschlüssel; ist er abgelaufen, wird er zuerst erneuert
    private func withToken(_ done: @escaping (String?) -> Void) {
        #if canImport(SpotifyiOS)
        guard let session = sessionManager.session else { done(nil); return }
        if !session.isExpired { done(session.accessToken); return }
        tokenWaiters.append(done)
        if tokenWaiters.count == 1 { sessionManager.renewSession() }
        #else
        done(nil)
        #endif
    }

    private func finishTokenWaiters(_ token: String?) {
        let w = tokenWaiters
        tokenWaiters = []
        w.forEach { $0(token) }
    }

    private static func items(_ json: [String: Any]) -> [[String: Any]] {
        json["items"] as? [[String: Any]] ?? []
    }

    /// Bild in passender Größe (Spotify liefert die größten zuerst)
    private static func image(_ any: Any?) -> URL? {
        let imgs = (any as? [[String: Any]]) ?? []
        let pick = imgs.last(where: { (($0["width"] as? Int) ?? 0) >= 200 }) ?? imgs.first
        return (pick?["url"] as? String).flatMap(URL.init)
    }

    private static func playlist(_ j: [String: Any]) -> SpotifyItem? {
        guard let uri = j["uri"] as? String, let name = j["name"] as? String else { return nil }
        let owner = (j["owner"] as? [String: Any])?["display_name"] as? String
        return SpotifyItem(uri: uri, title: name, subtitle: owner.map { "Playlist · " + $0 } ?? "Playlist", image: image(j["images"]))
    }

    private static func track(_ any: Any?) -> SpotifyItem? {
        guard let j = any as? [String: Any], let uri = j["uri"] as? String, let name = j["name"] as? String else { return nil }
        let artists = ((j["artists"] as? [[String: Any]]) ?? []).compactMap { $0["name"] as? String }.joined(separator: ", ")
        return SpotifyItem(uri: uri, title: name, subtitle: artists, image: image((j["album"] as? [String: Any])?["images"]))
    }

    // MARK: Interne Zustandswechsel (immer auf dem Hauptthread)

    #if canImport(SpotifyiOS)
    private func didGetSession(_ session: SPTSession, renewed: Bool) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: session, requiringSecureCoding: true) {
            Keychain.save(data, service: Self.keychainService)
        }
        finishTokenWaiters(session.accessToken)
        appRemote.connectionParameters.accessToken = session.accessToken
        if !renewed {
            phase = .connecting
            appRemote.connect()
            Task { await loadLibrary() }
        }
    }

    private func sessionFailed(_ error: Error) {
        finishTokenWaiters(nil)
        if phase == .connecting {
            phase = sessionManager.session == nil ? .signedOut : .disconnected
        }
    }

    private func didConnect() {
        quietAttempt = false
        phase = .connected
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: nil)
        appRemote.playerAPI?.getPlayerState { [weak self] result, _ in
            guard let state = result as? SPTAppRemotePlayerState else { return }
            DispatchQueue.main.async { self?.update(state) }
        }
    }

    private func connectFailed() {
        quietAttempt = false
        // Direkt nach der Rückkehr aus Spotify klappt es manchmal erst beim zweiten Versuch
        if phase == .connecting, !retriedConnect {
            retriedConnect = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.appRemote.connect() }
            return
        }
        phase = sessionManager.session == nil ? .signedOut : .disconnected
    }

    private func didDisconnect() {
        quietAttempt = false
        if phase == .connected || phase == .connecting {
            phase = sessionManager.session == nil ? .signedOut : .disconnected
        }
    }

    private func update(_ s: SPTAppRemotePlayerState) {
        let t = s.track
        now = SpotifyNowPlaying(uri: t.uri, title: t.name, artist: t.artist.name, album: t.album.name,
                                context: s.contextTitle, paused: s.isPaused, shuffle: s.playbackOptions.isShuffling,
                                canNext: s.playbackRestrictions.canSkipNext, canPrevious: s.playbackRestrictions.canSkipPrevious)
        guard coverURI != t.uri else { return }
        coverURI = t.uri
        appRemote.imageAPI?.fetchImage(forItem: t, with: CGSize(width: 600, height: 600)) { [weak self] result, _ in
            let img = result as? UIImage
            DispatchQueue.main.async {
                guard let self = self, self.coverURI == t.uri else { return }
                self.cover = img
            }
        }
    }
    #endif
}

// MARK: Rückmeldungen des Spotify SDK
// Können aus Hintergrund-Warteschlangen kommen → nonisolated, dann zurück auf den Hauptthread.

#if canImport(SpotifyiOS)
extension SpotifyCenter: SPTSessionManagerDelegate {
    nonisolated func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        DispatchQueue.main.async { self.didGetSession(session, renewed: false) }
    }

    nonisolated func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        DispatchQueue.main.async { self.didGetSession(session, renewed: true) }
    }

    nonisolated func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        DispatchQueue.main.async { self.sessionFailed(error) }
    }
}

extension SpotifyCenter: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        DispatchQueue.main.async { self.didConnect() }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        DispatchQueue.main.async { self.connectFailed() }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        DispatchQueue.main.async { self.didDisconnect() }
    }
}

extension SpotifyCenter: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        DispatchQueue.main.async { self.update(playerState) }
    }
}
#endif
