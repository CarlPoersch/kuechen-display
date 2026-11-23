import SwiftUI
import Combine

// ============================================================
// Spotify: Musik aus der eigenen Bibliothek abspielen, suchen und steuern –
// auf diesem Gerät (über die Spotify-App) oder auf anderen Geräten (Spotify Connect).
// Logik: Core/Spotify/SpotifyCenter.swift · Design: docs/specs/2026-11-23-spotify-design.md
// Anmeldung pro Gerät; Titel gezielt abspielen braucht Spotify Premium.
// ============================================================

enum SpotifyBucket {
    static let kind = BucketKind(
        id: "spotify", name: "Spotify", symbol: "music.note", tint: .green, art: .glance,
        interests: ["freizeit"], blurb: "Deine Playlists und Lieblingssongs abspielen, suchen und auf jedem Gerät steuern.",
        sizes: [.s, .m], defaultSize: .m,
        glance: { _, size in AnyView(SpotifyGlance(size: size)) },
        detail: { _ in AnyView(SpotifyApp()) },
        settings: { _ in AnyView(SpotifySettings()) }
    )
}

// MARK: Karte auf der Startseite

struct SpotifyGlance: View {
    let size: BucketSize
    @ObservedObject private var spotify = SpotifyCenter.shared

    var body: some View {
        Group {
            if let n = spotify.now, spotify.phase != .connecting {
                player(n)
            } else {
                switch spotify.phase {
                case .unavailable(let msg):
                    Text(msg).font(.subheadline).foregroundColor(Theme.secondary)
                case .signedOut:
                    prompt("Verbinde Spotify – dann startest du deine Musik direkt aus Hubert.", button: "Mit Spotify verbinden")
                case .failed(let msg):
                    prompt(msg, button: "Erneut versuchen")
                case .connecting:
                    HStack(spacing: 8) { ProgressView(); Text("Verbinde mit Spotify …").foregroundColor(Theme.secondary) }
                        .font(.subheadline)
                case .disconnected:
                    prompt("Spotify ist gerade nicht verbunden.", button: "Weiter hören")
                case .connected:
                    prompt("Gerade läuft nichts.", button: "Weiter hören")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { spotify.reconnectQuietly(); spotify.startWatching() }
        .onDisappear { spotify.stopWatching() }
    }

    private func prompt(_ text: String, button: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.subheadline).foregroundColor(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            Button(button) { spotify.connect() }
                .buttonStyle(.borderedProminent).tint(Theme.accent)
        }
    }

    private func player(_ n: SpotifyNowPlaying) -> some View {
        let side: CGFloat = size == .s ? 56 : 92
        return VStack(alignment: .leading, spacing: size == .s ? 8 : 12) {
            HStack(spacing: 12) {
                SpotifyCover(image: spotify.cover, url: n.imageURL).frame(width: side, height: side)
                VStack(alignment: .leading, spacing: 2) {
                    Text(n.title).font(.headline).lineLimit(size == .s ? 1 : 2)
                    Text(n.artist).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                    if size != .s {
                        if let d = n.device {
                            Label(d, systemImage: "hifispeaker.fill").font(.caption).foregroundColor(Theme.accent).lineLimit(1)
                        } else if !n.context.isEmpty {
                            Text(n.context).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            SpotifyControls(now: n, compact: true)
        }
    }
}

// MARK: Bedienknöpfe

struct SpotifyControls: View {
    let now: SpotifyNowPlaying?
    var compact = false
    @ObservedObject private var spotify = SpotifyCenter.shared

    var body: some View {
        let ready = now != nil
        HStack(spacing: compact ? 10 : 18) {
            if !compact {
                round("shuffle", label: "Zufällig", active: now?.shuffle ?? false, enabled: ready) { spotify.toggleShuffle() }
            }
            round("backward.fill", label: "Zurück", enabled: ready && (now?.canPrevious ?? true)) { spotify.previous() }
            Button {
                Haptic.tap(); spotify.togglePlay()
            } label: {
                Image(systemName: (now?.paused ?? true) ? "play.fill" : "pause.fill")
                    .font(compact ? .title3.weight(.semibold) : .title.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: compact ? 0 : 76, maxWidth: compact ? .infinity : 76, minHeight: compact ? 44 : 76)
                    .background(RoundedRectangle(cornerRadius: compact ? 12 : 38, style: .continuous).fill(Theme.accent))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel((now?.paused ?? true) ? "Abspielen" : "Pause")
            round("forward.fill", label: "Weiter", enabled: ready && (now?.canNext ?? true)) { spotify.next() }
            if !compact { Color.clear.frame(width: 52, height: 1) }   // Gegengewicht zu „Zufällig“, damit Play mittig sitzt
        }
        .frame(maxWidth: .infinity)
    }

    private func round(_ symbol: String, label: String, active: Bool = false, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tap(); action()
        } label: {
            Image(systemName: symbol)
                .font(compact ? .title3.weight(.semibold) : .title2.weight(.semibold))
                .foregroundColor(active ? Theme.accent : .primary)
                .frame(minWidth: compact ? 0 : 52, maxWidth: compact ? .infinity : 52, minHeight: compact ? 44 : 52)
                .background(RoundedRectangle(cornerRadius: compact ? 12 : 26, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemFill)))
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}

/// Cover des laufenden Titels: aus der Spotify-App (Bild) oder aus der Web API (Adresse)
struct SpotifyCover: View {
    let image: UIImage?
    var url: URL? = nil
    var body: some View {
        ZStack {
            Color(UIColor.tertiarySystemFill)
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let u = url {
                AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
            } else {
                Image(systemName: "music.note").font(.title2).foregroundColor(Theme.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Bild aus der Bibliothek (Web API)
struct SpotifyArtwork: View {
    let url: URL?
    var symbol = "music.note.list"
    var round = false
    var body: some View {
        AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
            ZStack { Color(UIColor.tertiarySystemFill); Image(systemName: symbol).foregroundColor(Theme.secondary) }
        }
        .clipShape(RoundedRectangle(cornerRadius: round ? 999 : 8, style: .continuous))
    }
}

/// „Lieblingssongs“-Kachel wie bei Spotify
struct SpotifyLikedArtwork: View {
    var body: some View {
        Image(systemName: "heart.fill").font(.title3).foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.29, green: 0.18, blue: 0.85), Color(red: 0.55, green: 0.75, blue: 0.95)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

// MARK: Bausteine für Listen

/// Abschnittsüberschrift klein, grau, in Großbuchstaben
struct SpotifySection<C: View>: View {
    let title: String
    @ViewBuilder let content: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary).padding(.leading, 4)
            content()
        }
    }
}

/// Weiße Gruppe im „Inset Grouped“-Stil
struct SpotifyGroup<C: View>: View {
    @ViewBuilder let content: () -> C
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Zeile: Bild, Titel, Untertitel, rechts Pfeil (Liste) oder Play
struct SpotifyRow: View {
    let item: SpotifyItem
    var small = false
    var number: Int? = nil
    @ObservedObject private var spotify = SpotifyCenter.shared

    var body: some View {
        let side: CGFloat = small ? 44 : 52
        let showNumber = number != nil && item.image == nil
        let playing = spotify.now?.uri == item.uri
        HStack(spacing: 12) {
            if showNumber {
                Text("\(number ?? 0)").font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary).frame(width: 28)
            } else if item.kind == .liked {
                SpotifyLikedArtwork().frame(width: side, height: side)
            } else {
                SpotifyArtwork(url: item.image, symbol: item.kind == .track ? "music.note" : (item.kind == .artist ? "person.fill" : "music.note.list"),
                               round: item.kind == .artist)
                    .frame(width: side, height: side)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).foregroundColor(playing ? Theme.accent : .primary).lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if playing {
                Image(systemName: "speaker.wave.2.fill").font(.subheadline).foregroundColor(Theme.accent)
            } else if item.isList {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundColor(Color(UIColor.tertiaryLabel))
            } else {
                Image(systemName: "play.fill").font(.subheadline).foregroundColor(Theme.accent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5).padding(.leading, 14 + (showNumber ? 28 : side) + 12)
        }
    }
}

/// Antippen: Listen öffnen, alles andere abspielen
struct SpotifyEntry: View {
    let item: SpotifyItem
    var small = false
    @ObservedObject private var spotify = SpotifyCenter.shared

    var body: some View {
        if item.isList {
            NavigationLink(destination: SpotifyListView(list: item)) { SpotifyRow(item: item, small: small) }
                .buttonStyle(.plain)
        } else {
            Button { Haptic.tap(); spotify.play(item.uri) } label: { SpotifyRow(item: item, small: small) }
                .buttonStyle(.plain)
        }
    }
}

// MARK: Spotify (App)

struct SpotifyApp: View {
    @ObservedObject private var spotify = SpotifyCenter.shared
    @State private var query = ""
    @State private var results: SpotifyCenter.SearchResult?
    @State private var searching = false
    @State private var searchFailed = false
    @State private var showDevices = false

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if spotify.isSignedIn { searchField }
                if isSearching {
                    searchResults
                } else {
                    playerCard
                    if spotify.isSignedIn { library }
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Spotify")
        .sheet(isPresented: $showDevices) { SpotifyDevicesSheet() }
        .overlay(alignment: .bottom) { messageBanner }
        .onAppear { spotify.reconnectQuietly(); spotify.startWatching() }
        .onDisappear { spotify.stopWatching() }
        .task { await spotify.loadLibrary() }
        .task(id: query) { await runSearch() }
    }

    // Suche

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
            TextField("Songs, Künstler, Alben, Playlists", text: $query)
                .disableAutocorrection(true)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Theme.secondary) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, 12).frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = nil; searchFailed = false; return }
        try? await Task.sleep(nanoseconds: 350_000_000)   // erst suchen, wenn kurz nicht getippt wird
        guard !Task.isCancelled else { return }
        searching = true
        let r = await spotify.search(q)
        guard !Task.isCancelled else { return }
        searching = false
        searchFailed = r == nil
        results = r
    }

    @ViewBuilder private var searchResults: some View {
        if searching && results == nil {
            HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 20)
        } else if searchFailed {
            Text("Die Suche hat gerade nicht geklappt.").foregroundColor(Theme.secondary)
        } else if let r = results {
            if r.isEmpty {
                Text("Nichts gefunden.").foregroundColor(Theme.secondary)
            }
            if !r.tracks.isEmpty {
                SpotifySection(title: "Songs") { SpotifyGroup { ForEach(r.tracks) { SpotifyEntry(item: $0, small: true) } } }
            }
            if !r.artists.isEmpty {
                SpotifySection(title: "Künstler") { SpotifyGroup { ForEach(Array(r.artists.prefix(5))) { SpotifyEntry(item: $0) } } }
            }
            if !r.albums.isEmpty {
                SpotifySection(title: "Alben") { SpotifyGroup { ForEach(r.albums) { SpotifyEntry(item: $0) } } }
            }
            if !r.playlists.isEmpty {
                SpotifySection(title: "Playlists") { SpotifyGroup { ForEach(r.playlists) { SpotifyEntry(item: $0) } } }
            }
        }
    }

    // Laufender Titel oder Verbinden

    private var playerCard: some View {
        VStack(spacing: 16) {
            playerContent
            if spotify.isSignedIn && !spotify.canControlDevices {
                Button { spotify.connect() } label: {
                    Label("Einmal neu verbinden für Geräte & Steuerung", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
    }

    @ViewBuilder private var playerContent: some View {
        if let n = spotify.now, spotify.phase != .connecting {
            nowPlaying(n)
        } else {
            switch spotify.phase {
            case .unavailable(let msg):
                notice("music.note", msg, button: nil)
            case .signedOut:
                notice("music.note", "Verbinde dein Spotify-Konto. Hubert öffnet dazu kurz die Spotify-App und kommt dann zurück.",
                       button: "Mit Spotify verbinden")
            case .failed(let msg):
                notice("exclamationmark.circle", msg, button: "Erneut versuchen")
            case .connecting:
                HStack(spacing: 10) { ProgressView(); Text("Verbinde mit Spotify …").foregroundColor(Theme.secondary) }
                    .frame(maxWidth: .infinity, minHeight: 120)
            case .connected:
                notice("play.circle", "Gerade läuft nichts. Wähle unten eine Playlist oder suche oben.", button: nil)
            case .disconnected:
                notice("play.circle", "Spotify ist gerade nicht verbunden.", button: "Weiter hören")
            }
        }
    }

    private func nowPlaying(_ n: SpotifyNowPlaying) -> some View {
        VStack(spacing: 14) {
            SpotifyCover(image: spotify.cover, url: n.imageURL)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 280)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            VStack(spacing: 3) {
                Text(n.title).font(.title3.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
                Text(n.artist).foregroundColor(Theme.secondary).lineLimit(1)
                if !n.context.isEmpty {
                    Text(n.context).font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
                }
            }
            SpotifyControls(now: n)
            if spotify.canControlDevices {
                Button { showDevices = true } label: {
                    Label(n.device ?? "Gerät wählen", systemImage: "hifispeaker.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).frame(minHeight: 36)
                        .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func notice(_ symbol: String, _ text: String, button: String?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 40)).foregroundColor(Theme.secondary)
            Text(text).font(.subheadline).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
            if let b = button {
                Button { spotify.connect() } label: {
                    Text(b).font(.headline).foregroundColor(.white)
                        .padding(.horizontal, 22).frame(minHeight: 48)
                        .background(Capsule().fill(Theme.accent))
                }
            }
            if spotify.canControlDevices {
                Button("Auf anderem Gerät abspielen") { showDevices = true }.font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // Bibliothek

    @ViewBuilder private var library: some View {
        if let err = spotify.libraryError {
            Text(err).font(.subheadline).foregroundColor(Theme.secondary)
        }
        if !spotify.recent.isEmpty {
            SpotifySection(title: "Zuletzt gehört") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(spotify.recent) { item in
                            Button { Haptic.tap(); spotify.play(item.uri) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    SpotifyArtwork(url: item.image, symbol: "music.note").frame(width: 120, height: 120)
                                    Text(item.title).font(.subheadline.weight(.medium)).foregroundColor(.primary).lineLimit(1)
                                    Text(item.subtitle).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                                }
                                .frame(width: 120, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        SpotifySection(title: "Bibliothek") {
            SpotifyGroup {
                if !spotify.liked.isEmpty {
                    SpotifyEntry(item: SpotifyItem(uri: spotify.likedURI ?? "spotify:liked", title: "Lieblingssongs",
                                                   subtitle: "Deine gespeicherten Songs", image: nil, kind: .liked))
                }
                ForEach(spotify.playlists) { SpotifyEntry(item: $0) }
                if spotify.playlists.isEmpty && spotify.liked.isEmpty {
                    Text(spotify.libraryLoading ? "Lade deine Bibliothek …" : "Noch keine Playlists")
                        .foregroundColor(Theme.secondary).padding(.vertical, 14).padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        Text("Die Musik läuft über Spotify – auf diesem Gerät oder einem anderen Spotify-Gerät. Einen bestimmten Song oder eine Playlist starten geht nur mit Spotify Premium.")
            .font(.footnote).foregroundColor(Theme.secondary)
    }

    @ViewBuilder private var messageBanner: some View {
        if let m = spotify.message {
            Text(m).font(.subheadline).foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Capsule().fill(Color.black.opacity(0.8)))
                .padding(.bottom, 24).padding(.horizontal, 20)
                .onTapGesture { spotify.clearMessage() }
                .task(id: m) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    spotify.clearMessage()
                }
        }
    }
}

// MARK: Playlist, Album, Lieblingssongs (Songliste)

struct SpotifyListView: View {
    let list: SpotifyItem
    @ObservedObject private var spotify = SpotifyCenter.shared
    @State private var tracks: SpotifyTrackList?

    /// Was als Ganzes abgespielt wird
    private var contextURI: String? {
        list.kind == .liked ? spotify.likedURI : list.uri
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let t = tracks {
                    if let note = t.note {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(note).font(.subheadline).foregroundColor(Theme.secondary)
                            if spotify.phase != .connected && t.tracks.isEmpty {
                                Button("Spotify verbinden") { spotify.connect(playing: contextURI ?? "") }
                                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                            }
                        }
                    }
                    if !t.tracks.isEmpty {
                        SpotifyGroup {
                            ForEach(Array(t.tracks.enumerated()), id: \.offset) { pair in
                                Button {
                                    Haptic.tap(); spotify.play(track: pair.element, index: pair.offset, in: contextURI)
                                } label: {
                                    SpotifyRow(item: pair.element, small: true, number: pair.offset + 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.top, 30)
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        // Songs neu laden, sobald Spotify verbunden ist (fremde Playlists gibt es nur darüber)
        .task(id: spotify.phase == .connected) { tracks = await spotify.tracks(of: list) }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            Group {
                if list.kind == .liked { SpotifyLikedArtwork() }
                else { SpotifyArtwork(url: list.image) }
            }
            .frame(width: 120, height: 120)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(list.title).font(.title2.weight(.bold)).lineLimit(2)
                Text(list.subtitle).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                Button {
                    Haptic.tap()
                    if list.kind == .liked { spotify.playLiked() } else { spotify.play(list.uri) }
                } label: {
                    Label("Abspielen", systemImage: "play.fill").font(.headline).foregroundColor(.white)
                        .padding(.horizontal, 18).frame(minHeight: 44)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.borderless)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: Geräte (Spotify Connect)

struct SpotifyDevicesSheet: View {
    @ObservedObject private var spotify = SpotifyCenter.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(spotify.devices) { d in
                        Button { Haptic.tap(); spotify.transfer(to: d) } label: { deviceRow(d) }
                    }
                    if spotify.devices.isEmpty && !spotify.devicesLoading {
                        Text("Keine Spotify-Geräte gefunden.").foregroundColor(Theme.secondary)
                    }
                } header: {
                    Text("Abspielen auf")
                } footer: {
                    Text("Hier erscheinen Geräte, auf denen Spotify gerade offen ist – Fernseher, Lautsprecher, Computer, Handys. Dieses Gerät taucht auf, sobald Spotify hier läuft.")
                }
                if spotify.phase != .connected {
                    Section {
                        Button { spotify.connect(); dismiss() } label: {
                            Label("Auf diesem Gerät abspielen", systemImage: UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone")
                        }
                    }
                }
                if let active = spotify.devices.first(where: { $0.active }), let vol = active.volume {
                    Section {
                        SpotifyVolumeSlider(device: active, start: vol).id(active.id)
                    } header: {
                        Text("Lautstärke · \(active.name)")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Geräte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { await spotify.loadDevices() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(spotify.devicesLoading)
                        .accessibilityLabel("Neu suchen")
                }
            }
            .task { await spotify.loadDevices() }
        }
        .navigationViewStyle(.stack)
    }

    private func deviceRow(_ d: SpotifyDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: d.symbol).font(.title3).frame(width: 32)
                .foregroundColor(d.active ? Theme.accent : .primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name).foregroundColor(d.active ? Theme.accent : .primary)
                if d.active { Text("Spielt gerade").font(.caption).foregroundColor(Theme.secondary) }
            }
            Spacer()
            if d.active { Image(systemName: "checkmark").foregroundColor(Theme.accent) }
        }
        .frame(minHeight: 44)
    }
}

struct SpotifyVolumeSlider: View {
    let device: SpotifyDevice
    @State private var value: Double
    @ObservedObject private var spotify = SpotifyCenter.shared

    init(device: SpotifyDevice, start: Int) {
        self.device = device
        _value = State(initialValue: Double(start))
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill").foregroundColor(Theme.secondary)
            Slider(value: $value, in: 0...100, step: 5, onEditingChanged: { editing in
                if !editing { spotify.setVolume(Int(value), on: device) }
            })
            Image(systemName: "speaker.wave.3.fill").foregroundColor(Theme.secondary)
        }
    }
}

// MARK: Einstellungen

struct SpotifySettings: View {
    @ObservedObject private var spotify = SpotifyCenter.shared

    var body: some View {
        switch spotify.phase {
        case .unavailable(let msg):
            Text(msg).foregroundColor(Theme.secondary)
        default:
            if spotify.isSignedIn {
                Label(spotify.phase == .connected ? "Verbunden" : "Angemeldet", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                if !spotify.canControlDevices {
                    Button { spotify.connect() } label: {
                        Label("Neu verbinden (für Geräte & Steuerung)", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                Button(role: .destructive) { spotify.signOut() } label: {
                    Label("Von Spotify abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Button { spotify.connect() } label: { Label("Mit Spotify verbinden", systemImage: "music.note") }
            }
        }
        Text("Die Anmeldung gilt nur für dieses Gerät. Hubert steuert die Spotify-App auf diesem Gerät oder andere Spotify-Geräte. Einen bestimmten Song oder eine Playlist starten geht nur mit Spotify Premium.")
            .font(.footnote).foregroundColor(Theme.secondary)
    }
}
