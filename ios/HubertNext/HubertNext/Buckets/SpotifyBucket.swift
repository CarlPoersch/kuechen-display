import SwiftUI
import Combine

// ============================================================
// Spotify: Musik aus der eigenen Bibliothek auf diesem Gerät abspielen und steuern.
// Hubert steuert die Spotify-App (Spotify iOS SDK), die Musik läuft dort.
// Logik: Core/Spotify/SpotifyCenter.swift
// Anmeldung pro Gerät; Titel gezielt abspielen braucht Spotify Premium.
// ============================================================

enum SpotifyBucket {
    static let kind = BucketKind(
        id: "spotify", name: "Spotify", symbol: "music.note", tint: .green, art: .glance,
        interests: ["freizeit"], blurb: "Deine Playlists und Lieblingssongs abspielen und steuern – über die Spotify-App.",
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
                if let n = spotify.now { player(n) }
                else { prompt("Spotify ist gerade nicht verbunden.", button: "Weiter hören") }
            case .connected:
                if let n = spotify.now { player(n) }
                else { prompt("Gerade läuft nichts.", button: "Weiter hören") }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { spotify.reconnectQuietly() }
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
                SpotifyCover(image: spotify.cover).frame(width: side, height: side)
                VStack(alignment: .leading, spacing: 2) {
                    Text(n.title).font(.headline).lineLimit(size == .s ? 1 : 2)
                    Text(n.artist).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                    if size != .s, !n.context.isEmpty {
                        Text(n.context).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
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
        let connected = spotify.phase == .connected
        HStack(spacing: compact ? 10 : 18) {
            if !compact {
                round("shuffle", label: "Zufällig", active: now?.shuffle ?? false, enabled: connected) { spotify.toggleShuffle() }
            }
            round("backward.fill", label: "Zurück", enabled: connected && (now?.canPrevious ?? true)) { spotify.previous() }
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
            round("forward.fill", label: "Weiter", enabled: connected && (now?.canNext ?? true)) { spotify.next() }
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

/// Cover des laufenden Titels (aus der Spotify-App)
struct SpotifyCover: View {
    let image: UIImage?
    var body: some View {
        ZStack {
            Color(UIColor.tertiarySystemFill)
            if let img = image { Image(uiImage: img).resizable().scaledToFill() }
            else { Image(systemName: "music.note").font(.title2).foregroundColor(Theme.secondary) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Bild aus der Bibliothek (Web API)
struct SpotifyArtwork: View {
    let url: URL?
    var symbol = "music.note.list"
    var body: some View {
        AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
            ZStack { Color(UIColor.tertiarySystemFill); Image(systemName: symbol).foregroundColor(Theme.secondary) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: Spotify (App)

struct SpotifyApp: View {
    @ObservedObject private var spotify = SpotifyCenter.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                playerCard
                if spotify.isSignedIn { library }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Spotify")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if spotify.isSignedIn {
                    Button { Task { await spotify.loadLibrary() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(spotify.libraryLoading)
                        .accessibilityLabel("Bibliothek neu laden")
                }
            }
        }
        .onAppear { spotify.reconnectQuietly() }
        .task { await spotify.loadLibrary() }
    }

    // Laufender Titel oder Verbinden

    @ViewBuilder private var playerCard: some View {
        VStack(spacing: 16) {
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
            case .connected, .disconnected:
                if let n = spotify.now {
                    nowPlaying(n)
                } else {
                    notice("play.circle", spotify.phase == .connected ? "Gerade läuft nichts. Wähle unten eine Playlist." : "Spotify ist gerade nicht verbunden.",
                           button: spotify.phase == .connected ? nil : "Weiter hören")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
    }

    private func nowPlaying(_ n: SpotifyNowPlaying) -> some View {
        VStack(spacing: 14) {
            SpotifyCover(image: spotify.cover)
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
            if spotify.phase == .disconnected {
                Button("Neu verbinden") { spotify.connect() }.font(.subheadline.weight(.semibold))
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
            section("Zuletzt gehört") {
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
        section("Playlists") {
            group {
                if !spotify.liked.isEmpty {
                    row(SpotifyItem(uri: "liked", title: "Lieblingssongs", subtitle: "\(spotify.liked.count)+ Titel", image: nil),
                        icon: "heart.fill") { spotify.playLiked() }
                }
                ForEach(spotify.playlists) { p in
                    row(p) { spotify.play(p.uri) }
                }
                if spotify.playlists.isEmpty && spotify.liked.isEmpty {
                    Text(spotify.libraryLoading ? "Lade deine Bibliothek …" : "Noch keine Playlists")
                        .foregroundColor(Theme.secondary).padding(.vertical, 14).padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        if !spotify.liked.isEmpty {
            section("Lieblingssongs") {
                group {
                    ForEach(spotify.liked.prefix(20)) { t in
                        row(t, small: true) { spotify.play(t.uri) }
                    }
                }
            }
        }
        Text("Die Musik läuft über die Spotify-App. Einen bestimmten Titel oder eine Playlist starten geht nur mit Spotify Premium.")
            .font(.footnote).foregroundColor(Theme.secondary)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary).padding(.leading, 4)
            content()
        }
    }

    /// Weiße Gruppe im „Inset Grouped“-Stil
    private func group<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ item: SpotifyItem, icon: String? = nil, small: Bool = false, action: @escaping () -> Void) -> some View {
        let side: CGFloat = small ? 44 : 52
        return Button { Haptic.tap(); action() } label: {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon).font(.title3).foregroundColor(.white)
                        .frame(width: side, height: side)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: [Color(red: 0.29, green: 0.18, blue: 0.85), Color(red: 0.55, green: 0.75, blue: 0.95)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
                } else {
                    SpotifyArtwork(url: item.image, symbol: small ? "music.note" : "music.note.list").frame(width: side, height: side)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).foregroundColor(.primary).lineLimit(1)
                    Text(item.subtitle).font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: spotify.now?.uri == item.uri ? "speaker.wave.2.fill" : "play.fill")
                    .font(.subheadline).foregroundColor(Theme.accent)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5).padding(.leading, 14 + side + 12)
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
                Button(role: .destructive) { spotify.signOut() } label: {
                    Label("Von Spotify abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } else {
                Button { spotify.connect() } label: { Label("Mit Spotify verbinden", systemImage: "music.note") }
            }
        }
        Text("Die Anmeldung gilt nur für dieses Gerät. Hubert steuert die Spotify-App – die muss installiert sein. Einen bestimmten Titel oder eine Playlist starten geht nur mit Spotify Premium.")
            .font(.footnote).foregroundColor(Theme.secondary)
    }
}
