import SwiftUI
import Combine
#if canImport(SpotifyiOS)
@preconcurrency import SpotifyiOS
#endif

// ============================================================
// Spotify: Hubert steuert die Spotify-App auf diesem Gerät und – über Spotify Connect –
// auch andere Geräte (Fernseher, Lautsprecher, Computer).
// - Anmeldung und Steuerung der Spotify-App über das Spotify iOS SDK ab 5.0 (App Remote, PKCE – kein Server nötig)
// - Bibliothek, Suche, Geräte und Steuerung anderer Geräte über die Spotify Web API
// Die Musik selbst spielt immer Spotify. Zum Verbinden wechselt Hubert kurz
// zu Spotify und kommt automatisch zurück.
// Die Anmeldung gilt pro Gerät (Schlüsselbund), nicht für den ganzen Haushalt.
// Spotify-Regeln seit Feb. 2026: Songlisten per Web API nur für eigene Playlists
// (fremde holt Hubert über die Spotify-App), Suche höchstens 10 Treffer je Art.
// Design: docs/specs/2026-11-23-spotify-design.md
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
    /// Bild aus der Web API (wenn nicht über die Spotify-App verbunden)
    var imageURL: URL? = nil
    /// Gerät, auf dem es läuft (nur bekannt über die Web API)
    var device: String? = nil
}

/// Ein Eintrag: Playlist, Album, Künstler oder Titel
struct SpotifyItem: Identifiable, Hashable {
    enum Kind: String { case playlist, album, artist, track, liked }
    let uri: String
    let title: String
    let subtitle: String
    let image: URL?
    var kind: Kind = .track
    /// Gehört dem Nutzer (nur dann liefert die Web API die Songliste)
    var own = false
    var id: String { uri }

    /// Kann man hineinschauen (Songliste)?
    var isList: Bool { kind == .playlist || kind == .album || kind == .liked }
}

/// Ein Spotify-Connect-Gerät
struct SpotifyDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let active: Bool
    let volume: Int?

    var symbol: String {
        switch type.lowercased() {
        case "computer": return "laptopcomputer"
        case "tablet": return "ipad"
        case "smartphone": return "iphone"
        case "speaker": return "hifispeaker"
        case "tv": return "tv"
        case "avr", "stb": return "hifispeaker.2"
        case "gameconsole", "game_console": return "gamecontroller"
        case "castvideo", "cast_video", "castaudio", "cast_audio": return "tv.and.mediabox"
        case "automobile": return "car"
        default: return "speaker.wave.2"
        }
    }
}

/// Songliste einer Playlist, eines Albums oder der Lieblingssongs
struct SpotifyTrackList {
    var tracks: [SpotifyItem]
    /// Hinweis, falls die Liste nicht (ganz) geladen werden konnte
    var note: String?
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
    @Published private(set) var devices: [SpotifyDevice] = []
    @Published private(set) var devicesLoading = false
    @Published private(set) var message: String?

    private static let keychainService = "com.carlpoersch.HubertNext.spotify"
    private(set) var userId: String?
    private var coverURI: String?
    private var retriedConnect = false
    private var quietAttempt = false
    private var tokenWaiters: [(String?) -> Void] = []
    private var watchers = 0
    private var pollTask: Task<Void, Never>?

    /// Angemeldet (Zugang im Schlüsselbund), egal ob gerade verbunden
    var isSignedIn: Bool {
        #if canImport(SpotifyiOS)
        if case .unavailable = phase { return false }
        return sessionManager.session != nil
        #else
        return false
        #endif
    }

    /// Hat die Anmeldung schon die Rechte für Geräte und Steuerung? (ältere Anmeldungen nicht)
    var canControlDevices: Bool {
        #if canImport(SpotifyiOS)
        guard let s = sessionManager.session else { return false }
        return s.scope.contains(.userModifyPlaybackState) && s.scope.contains(.userReadPlaybackState)
        #else
        return false
        #endif
    }

    /// Lieblingssongs als abspielbare Sammlung
    var likedURI: String? { userId.map { "spotify:user:\($0):collection" } }

    #if canImport(SpotifyiOS)
    /// Rechte: Spotify-App steuern, Bibliothek lesen, andere Geräte sehen und steuern
    private let scope: SPTScope = [.appRemoteControl, .playlistReadPrivate, .playlistReadCollaborative,
                                   .userLibraryRead, .userReadRecentlyPlayed,
                                   .userReadPlaybackState, .userModifyPlaybackState, .userReadCurrentlyPlaying]

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
        playlists = []; liked = []; recent = []; devices = []; libraryError = nil
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
        if watchers > 0 { Task { await refreshWebPlayer() } }
    }

    /// App geht in den Hintergrund: Verbindung lösen (Spotify spielt weiter)
    func appEnteredBackground() {
        #if canImport(SpotifyiOS)
        guard phase == .connected else { return }
        appRemote.disconnect()
        phase = .disconnected
        #endif
    }

    // MARK: Mitlesen, solange eine Spotify-Ansicht offen ist

    /// Karte oder App sichtbar: Wiedergabe regelmäßig abfragen, wenn die Spotify-App nicht verbunden ist
    /// (z. B. Musik läuft auf dem Fernseher)
    func startWatching() {
        watchers += 1
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                if self.isSignedIn, self.phase != .connected, self.phase != .connecting {
                    await self.refreshWebPlayer()
                }
                try? await Task.sleep(nanoseconds: 8_000_000_000)
            }
        }
    }

    func stopWatching() {
        watchers = max(0, watchers - 1)
        if watchers == 0 { pollTask?.cancel(); pollTask = nil }
    }

    /// Wiedergabe über die Web API (auf welchem Gerät auch immer)
    func refreshWebPlayer() async {
        guard isSignedIn, canControlDevices else { return }
        guard let j = try? await request("GET", "me/player?additional_types=episode") else { return }
        // Spotify-App ist inzwischen verbunden → deren Stand gilt, nur der Gerätename kommt dazu
        if phase == .connected, now != nil {
            let dev = (j["device"] as? [String: Any])?["name"] as? String
            if now?.device != dev { now?.device = dev }
            return
        }
        guard let item = j["item"] as? [String: Any], let uri = item["uri"] as? String else {
            if phase != .connected { now = nil }
            return
        }
        let t = Self.track(item)
        let ctxURI = (j["context"] as? [String: Any])?["uri"] as? String
        let ctxName = ctxURI.flatMap { u in playlists.first { $0.uri == u }?.title } ?? ""
        now = SpotifyNowPlaying(uri: uri, title: t?.title ?? "", artist: t?.subtitle ?? "",
                                album: ((item["album"] as? [String: Any])?["name"] as? String) ?? "",
                                context: ctxName, paused: !((j["is_playing"] as? Bool) ?? false),
                                shuffle: (j["shuffle_state"] as? Bool) ?? false, canNext: true, canPrevious: true,
                                imageURL: t?.image, device: (j["device"] as? [String: Any])?["name"] as? String)
        if phase != .connected { cover = nil; coverURI = nil }
    }

    // MARK: Steuern

    func togglePlay() {
        #if canImport(SpotifyiOS)
        if let api = connectedPlayer() {
            if now?.paused ?? true { api.resume(nil) } else { api.pause(nil) }
            return
        }
        #endif
        if now != nil, canControlDevices {
            let paused = now?.paused ?? true
            now?.paused = !paused
            webCommand("PUT", paused ? "me/player/play" : "me/player/pause")
        } else {
            connect()
        }
    }

    func next() {
        #if canImport(SpotifyiOS)
        if let api = connectedPlayer() { api.skip(toNext: nil); return }
        #endif
        webCommand("POST", "me/player/next")
    }

    func previous() {
        #if canImport(SpotifyiOS)
        if let api = connectedPlayer() { api.skip(toPrevious: nil); return }
        #endif
        webCommand("POST", "me/player/previous")
    }

    func toggleShuffle() {
        guard let n = now else { return }
        #if canImport(SpotifyiOS)
        if let api = connectedPlayer() { api.setShuffle(!n.shuffle, callback: nil); return }
        #endif
        now?.shuffle = !n.shuffle
        webCommand("PUT", "me/player/shuffle?state=\(!n.shuffle)")
    }

    /// Befehl an das gerade aktive Gerät (Web API), danach Stand neu holen
    private func webCommand(_ method: String, _ path: String, body: [String: Any]? = nil) {
        guard canControlDevices else { connect(); return }
        Task {
            do { _ = try await request(method, path, body: body) }
            catch SpotifyError.noDevice { message = "Gerade ist kein Spotify-Gerät aktiv. Wähle eins unter „Geräte“." }
            catch { message = "Spotify hat den Befehl nicht angenommen." }
            try? await Task.sleep(nanoseconds: 600_000_000)
            await refreshWebPlayer()
        }
    }

    func clearMessage() { message = nil }

    /// Playlist, Album, Künstler oder Titel abspielen.
    /// Verbunden → über die Spotify-App. Läuft gerade ein anderes Gerät → dort.
    /// Sonst öffnet Hubert Spotify kurz und spielt dann.
    func play(_ uri: String) {
        #if canImport(SpotifyiOS)
        if let api = connectedPlayer() {
            api.play(uri) { [weak self] _, error in
                if error != nil { DispatchQueue.main.async { self?.connect(playing: uri) } }
            }
            return
        }
        #endif
        if remoteDeviceActive {
            let single = uri.contains(":track:") || uri.contains(":episode:")
            let body: [String: Any] = single ? ["uris": [uri]] : ["context_uri": uri]
            webCommand("PUT", "me/player/play", body: body)
        } else {
            connect(playing: uri)
        }
    }

    /// Song aus einer Liste abspielen – die Liste läuft danach weiter
    func play(track: SpotifyItem, index: Int, in context: String?) {
        guard let ctx = context else { play(track.uri); return }
        #if canImport(SpotifyiOS)
        if appRemote.isConnected, let content = appRemote.contentAPI, let api = appRemote.playerAPI {
            content.fetchContentItem(forURI: ctx) { [weak self] result, _ in
                DispatchQueue.main.async {
                    if let item = result as? SPTAppRemoteContentItem, item.isPlayable {
                        api.play(item, skipToTrackIndex: index) { _, error in
                            if error != nil { DispatchQueue.main.async { self?.play(track.uri) } }
                        }
                    } else {
                        self?.play(track.uri)
                    }
                }
            }
            return
        }
        #endif
        if remoteDeviceActive {
            webCommand("PUT", "me/player/play", body: ["context_uri": ctx, "offset": ["uri": track.uri]])
        } else {
            connect(playing: track.uri)
        }
    }

    /// Lieblingssongs als Ganzes abspielen
    func playLiked() {
        if let u = likedURI { play(u) }
        else if let first = liked.first { play(first.uri) }
    }

    /// Läuft (laut Web API) gerade ein Gerät, das Hubert steuern kann?
    private var remoteDeviceActive: Bool { canControlDevices && now?.device != nil }

    #if canImport(SpotifyiOS)
    private func connectedPlayer() -> SPTAppRemotePlayerAPI? {
        guard appRemote.isConnected else { return nil }
        return appRemote.playerAPI
    }
    #endif

    // MARK: Geräte (Spotify Connect)

    func loadDevices() async {
        guard canControlDevices else { return }
        devicesLoading = true
        defer { devicesLoading = false }
        guard let j = try? await request("GET", "me/player/devices") else { return }
        devices = ((j["devices"] as? [[String: Any]]) ?? []).compactMap { d in
            guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
            return SpotifyDevice(id: id, name: name, type: (d["type"] as? String) ?? "",
                                 active: (d["is_active"] as? Bool) ?? false, volume: d["volume_percent"] as? Int)
        }
    }

    /// Wiedergabe auf ein anderes Gerät verschieben (spielt dort weiter)
    func transfer(to device: SpotifyDevice) {
        devices = devices.map { SpotifyDevice(id: $0.id, name: $0.name, type: $0.type, active: $0.id == device.id, volume: $0.volume) }
        now?.device = device.name
        Task {
            do { _ = try await request("PUT", "me/player", body: ["device_ids": [device.id], "play": true]) }
            catch { message = "\(device.name) hat nicht reagiert. Ist das Gerät an?" }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await loadDevices()
            await refreshWebPlayer()
        }
    }

    func setVolume(_ percent: Int, on device: SpotifyDevice) {
        webCommand("PUT", "me/player/volume?volume_percent=\(max(0, min(100, percent)))&device_id=\(device.id)")
    }

    // MARK: Bibliothek (Web API)

    func loadLibrary() async {
        guard isSignedIn, !libraryLoading else { return }
        libraryLoading = true
        defer { libraryLoading = false }
        do {
            // Playlists sind Pflicht (zeigen auch, ob das Konto freigegeben ist);
            // Lieblingssongs und Verlauf dürfen einzeln fehlen, falls Spotify einen Endpunkt sperrt
            if userId == nil { userId = (try? await request("GET", "me"))?["id"] as? String }
            let pj = try await request("GET", "me/playlists?limit=50")
            playlists = Self.items(pj).compactMap { Self.playlist($0, me: userId) }
            if let lj = try? await request("GET", "me/tracks?limit=50") {
                liked = Self.items(lj).compactMap { Self.track($0["track"]) }
            }
            if let rj = try? await request("GET", "me/player/recently-played?limit=30") {
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

    /// Songs einer Playlist, eines Albums oder der Lieblingssongs
    func tracks(of list: SpotifyItem) async -> SpotifyTrackList {
        switch list.kind {
        case .liked:
            var out: [SpotifyItem] = []
            for page in 0..<4 {   // bis 200 Songs
                guard let j = try? await request("GET", "me/tracks?limit=50&offset=\(page * 50)") else { break }
                let batch = Self.items(j).compactMap { Self.track($0["track"]) }
                out += batch
                if batch.count < 50 { break }
            }
            return SpotifyTrackList(tracks: out, note: out.isEmpty ? "Deine Lieblingssongs ließen sich gerade nicht laden." : nil)
        case .album:
            let id = Self.spotifyId(list.uri)
            guard let j = try? await request("GET", "albums/\(id)/tracks?limit=50") else {
                return await appTracks(list.uri, fallback: "Das Album ließ sich gerade nicht laden.")
            }
            let out = Self.items(j).compactMap { t -> SpotifyItem? in
                guard let item = Self.track(t) else { return nil }
                return SpotifyItem(uri: item.uri, title: item.title, subtitle: item.subtitle, image: list.image)
            }
            return SpotifyTrackList(tracks: out, note: nil)
        default:
            // Seit Feb. 2026 liefert die Web API Songlisten nur für eigene Playlists → sonst über die Spotify-App
            let id = Self.spotifyId(list.uri)
            if let j = try? await request("GET", "playlists/\(id)/items?limit=100") {
                let out = Self.items(j).compactMap { Self.track($0["item"] ?? $0["track"]) }
                if !out.isEmpty { return SpotifyTrackList(tracks: out, note: nil) }
            }
            return await appTracks(list.uri, fallback: "Die Songs dieser Playlist zeigt Spotify nur über die Spotify-App. Verbinde Spotify, dann erscheinen sie hier.")
        }
    }

    /// Songliste über die verbundene Spotify-App (klappt auch für fremde Playlists)
    private func appTracks(_ uri: String, fallback: String) async -> SpotifyTrackList {
        #if canImport(SpotifyiOS)
        guard appRemote.isConnected, let content = appRemote.contentAPI else { return SpotifyTrackList(tracks: [], note: fallback) }
        let items: [SpotifyItem] = await withCheckedContinuation { cont in
            content.fetchContentItem(forURI: uri) { result, _ in
                guard let item = result as? SPTAppRemoteContentItem else { cont.resume(returning: []); return }
                content.fetchChildren(of: item) { children, _ in
                    let list = (children as? [SPTAppRemoteContentItem]) ?? []
                    cont.resume(returning: list.map {
                        SpotifyItem(uri: $0.uri, title: $0.title ?? "", subtitle: $0.subtitle ?? "", image: nil)
                    })
                }
            }
        }
        return SpotifyTrackList(tracks: items, note: items.isEmpty ? fallback : nil)
        #else
        return SpotifyTrackList(tracks: [], note: fallback)
        #endif
    }

    // MARK: Suche (Web API, höchstens 10 Treffer je Art)

    struct SearchResult {
        var tracks: [SpotifyItem] = []
        var artists: [SpotifyItem] = []
        var albums: [SpotifyItem] = []
        var playlists: [SpotifyItem] = []
        var isEmpty: Bool { tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty }
    }

    func search(_ query: String) async -> SearchResult? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return SearchResult() }
        guard let j = try? await request("GET", "search?q=\(enc)&type=track,artist,album,playlist&limit=10") else { return nil }
        func list(_ key: String) -> [[String: Any]] {
            (((j[key] as? [String: Any])?["items"] as? [Any]) ?? []).compactMap { $0 as? [String: Any] }
        }
        var r = SearchResult()
        r.tracks = list("tracks").compactMap { Self.track($0) }
        r.artists = list("artists").compactMap { a in
            guard let uri = a["uri"] as? String, let name = a["name"] as? String else { return nil }
            return SpotifyItem(uri: uri, title: name, subtitle: "Künstler", image: Self.image(a["images"]), kind: .artist)
        }
        r.albums = list("albums").compactMap { a in
            guard let uri = a["uri"] as? String, let name = a["name"] as? String else { return nil }
            let artists = ((a["artists"] as? [[String: Any]]) ?? []).compactMap { $0["name"] as? String }.joined(separator: ", ")
            return SpotifyItem(uri: uri, title: name, subtitle: "Album · " + artists, image: Self.image(a["images"]), kind: .album)
        }
        r.playlists = list("playlists").compactMap { Self.playlist($0, me: userId) }
        return r
    }

    // MARK: Web API

    private enum SpotifyError: Error { case signedOut, forbidden, noDevice, http(Int) }

    private func request(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let token = await freshToken() else { throw SpotifyError.signedOut }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/" + path)!)
        req.httpMethod = method
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if method != "GET" {
            req.httpBody = Data()
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw SpotifyError.signedOut }
        if code == 403 { throw SpotifyError.forbidden }
        if code == 404, path.hasPrefix("me/player") { throw SpotifyError.noDevice }
        guard (200..<300).contains(code) else { throw SpotifyError.http(code) }
        if data.isEmpty { return [:] }
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
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
        ((json["items"] as? [Any]) ?? []).compactMap { $0 as? [String: Any] }
    }

    /// ID aus einer Spotify-URI (spotify:playlist:ID)
    private static func spotifyId(_ uri: String) -> String {
        uri.split(separator: ":").last.map(String.init) ?? uri
    }

    /// Bild in passender Größe (Spotify liefert die größten zuerst)
    private static func image(_ any: Any?) -> URL? {
        let imgs = (any as? [[String: Any]]) ?? []
        let pick = imgs.last(where: { (($0["width"] as? Int) ?? 0) >= 200 }) ?? imgs.first
        return (pick?["url"] as? String).flatMap(URL.init)
    }

    private static func playlist(_ j: [String: Any], me: String?) -> SpotifyItem? {
        guard let uri = j["uri"] as? String, let name = j["name"] as? String else { return nil }
        let ownerDict = j["owner"] as? [String: Any]
        let owner = ownerDict?["display_name"] as? String
        let mine = me != nil && (ownerDict?["id"] as? String) == me
        let collab = (j["collaborative"] as? Bool) ?? false
        return SpotifyItem(uri: uri, title: name, subtitle: owner.map { "Playlist · " + $0 } ?? "Playlist",
                           image: image(j["images"]), kind: .playlist, own: mine || collab)
    }

    private static func track(_ any: Any?) -> SpotifyItem? {
        guard let j = any as? [String: Any], let uri = j["uri"] as? String, let name = j["name"] as? String else { return nil }
        let artists = ((j["artists"] as? [[String: Any]]) ?? []).compactMap { $0["name"] as? String }.joined(separator: ", ")
        let show = (j["show"] as? [String: Any])?["name"] as? String
        let img = image((j["album"] as? [String: Any])?["images"]) ?? image(j["images"])
        return SpotifyItem(uri: uri, title: name, subtitle: artists.isEmpty ? (show ?? "") : artists, image: img)
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
        Task { await refreshWebPlayer() }   // Gerätename dazu
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
                                canNext: s.playbackRestrictions.canSkipNext, canPrevious: s.playbackRestrictions.canSkipPrevious,
                                imageURL: nil, device: now?.device)
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
