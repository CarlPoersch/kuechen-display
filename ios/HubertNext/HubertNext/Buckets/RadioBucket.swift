import SwiftUI
import Combine
import AVFoundation
import AVKit
import MediaPlayer

// ============================================================
// Radio: 15 Sender zum Start (Bayern, Regensburg, Deutschlandfunk & Co.), eigene dazu über die Suche.
// Stream-Adressen kommen frisch aus dem offenen Radio-Verzeichnis radio-browser.info
// (Sender ändern ihre Adressen gelegentlich) – mit fester Adresse als Rückfall.
// Läuft im Hintergrund weiter, mit Steuerung auf dem Sperrbildschirm, AirPlay und Schlaf-Timer.
// Die Senderliste gehört zum Bucket und ist damit im ganzen Haushalt gleich.
// ============================================================

struct RadioStation: Codable, Hashable, Identifiable {
    var id: String              // radio-browser stationuuid oder eigener Schlüssel
    var name: String
    var search: String? = nil   // Suchname im Verzeichnis (für die Startsender)
    var url: String? = nil      // feste Adresse (Rückfall bzw. aus der Suche)
    var favicon: String? = nil
    var color: String? = nil    // Hex-Farbe für das Symbol ohne Logo

    /// Kürzel für das Symbol, z. B. „B3“, „DLF“
    var initials: String {
        let known: [String: String] = ["Bayern 1": "B1", "Bayern 2": "B2", "Bayern 3": "B3", "BR-Klassik": "BR♪", "B5 aktuell": "B5",
                                       "Deutschlandfunk": "DLF", "Deutschlandfunk Nova": "Nova", "1LIVE": "1L", "SWR3": "SWR3",
                                       "Antenne Bayern": "AB", "Rock Antenne": "Rock", "Gong FM": "Gong", "PULS": "Puls", "egoFM": "ego",
                                       "Energy München": "NRJ"]
        if let k = known[name] { return k }
        let words = name.split(separator: " ").prefix(2)
        return words.map { String($0.prefix(1)) }.joined().uppercased()
    }

    static let defaults: [RadioStation] = [
        .init(id: "bayern3", name: "Bayern 3", search: "Bayern 3", url: "https://dispatcher.rndfnk.com/br/br3/live/mp3/mid", color: "1E88E5"),
        .init(id: "bayern1", name: "Bayern 1", search: "Bayern 1", url: "https://dispatcher.rndfnk.com/br/br1/obb/mp3/mid", color: "0D47A1"),
        .init(id: "antenne", name: "Antenne Bayern", search: "Antenne Bayern", url: "https://stream.antenne.de/antenne", color: "E53935"),
        .init(id: "rockantenne", name: "Rock Antenne", search: "Rock Antenne", url: "https://stream.rockantenne.de/rockantenne/stream/mp3", color: "212121"),
        .init(id: "gongfm", name: "Gong FM", search: "Gong FM", color: "F4511E"),
        .init(id: "bayern2", name: "Bayern 2", search: "Bayern 2", url: "https://dispatcher.rndfnk.com/br/br2/live/mp3/mid", color: "00897B"),
        .init(id: "brklassik", name: "BR-Klassik", search: "BR-Klassik", url: "https://dispatcher.rndfnk.com/br/brklassik/live/mp3/mid", color: "6D4C41"),
        .init(id: "b5", name: "B5 aktuell", search: "B5 aktuell", url: "https://dispatcher.rndfnk.com/br/b5aktuell/live/mp3/mid", color: "546E7A"),
        .init(id: "puls", name: "PULS", search: "Puls", url: "https://dispatcher.rndfnk.com/br/puls/live/mp3/mid", color: "8E24AA"),
        .init(id: "dlf", name: "Deutschlandfunk", search: "Deutschlandfunk", url: "https://st01.sslstream.dlf.de/dlf/01/128/mp3/stream.mp3", color: "1565C0"),
        .init(id: "dlfnova", name: "Deutschlandfunk Nova", search: "Deutschlandfunk Nova", url: "https://st03.sslstream.dlf.de/dlf/03/128/mp3/stream.mp3", color: "00ACC1"),
        .init(id: "1live", name: "1LIVE", search: "1LIVE", url: "https://wdr-1live-live.icecastssl.wdr.de/wdr/1live/live/mp3/128/stream.mp3", color: "D81B60"),
        .init(id: "swr3", name: "SWR3", search: "SWR3", url: "https://liveradio.swr.de/sw282p3/swr3/play.mp3", color: "FB8C00"),
        .init(id: "egofm", name: "egoFM", search: "egoFM", color: "43A047"),
        .init(id: "energy", name: "Energy München", search: "Energy München", color: "C62828"),
    ]

    // Liste im Bucket (als JSON-Text gespeichert)
    static func list(_ config: [String: JSON]) -> [RadioStation] {
        guard let s = config["stations"]?.string, let d = s.data(using: .utf8),
              let l = try? JSONDecoder().decode([RadioStation].self, from: d) else { return defaults }
        return l
    }
    static func store(_ list: [RadioStation], in config: inout [String: JSON]) {
        if let d = try? JSONEncoder().encode(list), let s = String(data: d, encoding: .utf8) { config["stations"] = .string(s) }
    }
}

extension Color {
    init(hex: String?) {
        let v = UInt64(hex ?? "", radix: 16) ?? 0x8E8E93
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

// MARK: Verzeichnis (radio-browser.info)

enum RadioDirectory {
    struct Hit: Decodable, Identifiable {
        let stationuuid: String
        let name: String
        let url_resolved: String
        let favicon: String?
        let country: String?
        let tags: String?
        let bitrate: Int?
        let lastcheckok: Int?
        var id: String { stationuuid }
    }

    private static let base = "https://de1.api.radio-browser.info/json/stations/search"

    static func search(_ name: String, limit: Int = 25) async -> [Hit] {
        var c = URLComponents(string: base)!
        c.queryItems = [.init(name: "name", value: name), .init(name: "limit", value: "\(limit)"),
                        .init(name: "hidebroken", value: "true"), .init(name: "order", value: "clickcount"),
                        .init(name: "reverse", value: "true")]
        guard let url = c.url else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Hubert/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8
        guard let (d, _) = try? await URLSession.shared.data(for: req) else { return [] }
        return (try? JSONDecoder().decode([Hit].self, from: d)) ?? []
    }

    /// Beste Adresse für einen Startsender: gleichnamig, in Deutschland, zuletzt erreichbar, meistgehört
    static func resolve(_ s: RadioStation) async -> (url: String, favicon: String?)? {
        guard let q = s.search else { return nil }
        let hits = await search(q, limit: 15)
        let norm: (String) -> String = { $0.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "") }
        let want = norm(q)
        let pick = hits.first { norm($0.name) == want && ($0.country ?? "").contains("Germany") && $0.lastcheckok != 0 }
            ?? hits.first { norm($0.name).hasPrefix(want) && $0.lastcheckok != 0 }
        return pick.map { ($0.url_resolved, $0.favicon.flatMap { $0.isEmpty ? nil : $0 }) }
    }
}

// MARK: Abspielen

final class RadioPlayer: NSObject, ObservableObject, AVPlayerItemMetadataOutputPushDelegate {
    static let shared = RadioPlayer()

    @Published private(set) var current: RadioStation?
    @Published private(set) var playing = false
    @Published private(set) var loading = false
    @Published private(set) var song: String?          // „Interpret – Titel“, wenn der Sender es mitschickt
    @Published private(set) var failed: String?
    @Published private(set) var sleepAt: Date?
    @Published private(set) var logos: [String: String] = [:]   // Sender-ID → Logo-Adresse

    private var player: AVPlayer?
    private var queue: [RadioStation] = []
    private var resolved: [String: String] = [:]                 // Sender-ID → Stream (aus dem Verzeichnis)
    private var statusObs: NSKeyValueObservation?
    private var sleepTimer: Timer?
    private var remoteReady = false

    private override init() {
        super.init()
        if let r = UserDefaults.standard.dictionary(forKey: "hubert.radio.resolved") as? [String: String] { resolved = r }
        if let l = UserDefaults.standard.dictionary(forKey: "hubert.radio.logos") as? [String: String] { logos = l }
    }

    func isCurrent(_ s: RadioStation) -> Bool { current?.id == s.id }

    /// Sender spielen (oder pausieren, wenn er schon läuft). `list` = für Vor/Zurück
    func toggle(_ s: RadioStation, in list: [RadioStation]) {
        if isCurrent(s) { playing ? pause() : resume() } else { play(s, in: list) }
    }

    func play(_ s: RadioStation, in list: [RadioStation]) {
        queue = list
        current = s
        song = nil
        failed = nil
        loading = true
        playing = true
        setupRemote()
        updateNowPlaying()
        Task {
            var address = resolved[s.id]
            if s.search != nil, let r = await RadioDirectory.resolve(s) {
                address = r.url
                resolved[s.id] = r.url
                if let f = r.favicon { logos[s.id] = f }
                UserDefaults.standard.set(resolved, forKey: "hubert.radio.resolved")
                UserDefaults.standard.set(logos, forKey: "hubert.radio.logos")
            }
            guard current?.id == s.id else { return }
            guard let a = address ?? s.url, let url = URL(string: a) else {
                loading = false; playing = false; failed = "\(s.name) ist gerade nicht erreichbar."
                return
            }
            start(url)
        }
    }

    private func start(_ url: URL) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, policy: .longFormAudio)
        try? session.setActive(true)
        let item = AVPlayerItem(url: url)
        let meta = AVPlayerItemMetadataOutput(identifiers: nil)
        meta.setDelegate(self, queue: .main)
        item.add(meta)
        statusObs = item.observe(\.status, options: [.new]) { it, _ in
            let failedNow = it.status == .failed
            let ready = it.status == .readyToPlay
            Task { @MainActor in
                let p = RadioPlayer.shared
                if ready { p.loading = false }
                if failedNow {
                    p.loading = false; p.playing = false
                    p.failed = "\(p.current?.name ?? "Der Sender") lässt sich gerade nicht abspielen."
                }
            }
        }
        if player == nil { player = AVPlayer() }
        player?.replaceCurrentItem(with: item)
        player?.play()
    }

    func pause() {
        player?.pause()
        playing = false
        updateNowPlaying()
    }

    func resume() {
        guard let s = current else { return }
        // Live-Radio: nach einer Pause frisch verbinden, damit man nicht hinterherhängt
        play(s, in: queue)
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playing = false; loading = false; song = nil; current = nil
        setSleep(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func next(_ step: Int = 1) {
        guard !queue.isEmpty else { return }
        let i = queue.firstIndex { $0.id == current?.id } ?? -1
        let n = (i + step + queue.count) % queue.count
        play(queue[n], in: queue)
    }

    /// Schlaf-Timer: nach x Minuten ausschalten (nil = aus)
    func setSleep(_ minutes: Int?) {
        sleepTimer?.invalidate(); sleepTimer = nil
        guard let m = minutes else { sleepAt = nil; return }
        sleepAt = Date().addingTimeInterval(Double(m) * 60)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: Double(m) * 60, repeats: false) { _ in
            Task { @MainActor in RadioPlayer.shared.stop() }
        }
    }

    // Titel, den der Sender mitschickt (ICY „StreamTitle“)
    nonisolated func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                                    from track: AVPlayerItemTrack?) {
        let item = groups.first?.items.first { ($0.commonKey == .commonKeyTitle) || ($0.identifier?.rawValue.contains("StreamTitle") ?? false) }
            ?? groups.first?.items.first
        let t = item?.stringValue
        Task { @MainActor in
            let p = RadioPlayer.shared
            p.song = RadioPlayer.clean(t, station: p.current?.name)
            p.updateNowPlaying()
        }
    }

    /// Songtitel vom Sender aufräumen: „*** Verkehr“ → „Verkehr“, Sendername allein → nichts
    static func clean(_ raw: String?, station: String?) -> String? {
        guard var t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        let junk = CharacterSet(charactersIn: "*#~_|•·-–— ").union(.whitespaces)
        t = t.trimmingCharacters(in: junk)
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        // Werbe-/Kennungstexte ohne Inhalt
        let lower = t.lowercased()
        if t.isEmpty || lower == station?.lowercased() || lower.hasPrefix("http") || lower.contains("jetzt hören") { return nil }
        // GROSSBUCHSTABEN lesbar machen
        if t == t.uppercased() && t.count > 4 { t = t.capitalized }
        return t
    }

    /// „Interpret – Titel“ trennen (wenn der Sender es so schickt)
    var songParts: (title: String, artist: String?)? {
        guard let s = song else { return nil }
        for sep in [" - ", " – ", " — ", " / "] {
            let parts = s.components(separatedBy: sep)
            if parts.count >= 2, !parts[0].isEmpty, !parts[1].isEmpty {
                return (parts.dropFirst().joined(separator: sep), parts[0])
            }
        }
        return (s, nil)
    }

    // MARK: Sperrbildschirm und Kontrollzentrum

    private var artCache: [String: UIImage] = [:]

    func updateNowPlaying() {
        guard let s = current else { return }
        // Mit Song: „Titel“ / „Interpret · Sender“; sonst „Sender“ / „Live-Radio“
        let parts = songParts
        var info: [String: Any] = [MPMediaItemPropertyTitle: parts?.title ?? s.name,
                                   MPMediaItemPropertyArtist: parts.map { p in [p.artist, s.name].compactMap { $0 }.joined(separator: " · ") } ?? "Live-Radio",
                                   MPNowPlayingInfoPropertyIsLiveStream: true,
                                   MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0]
        if let img = artCache[s.id] ?? Self.initialsArt(s) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        if artCache[s.id] == nil { loadArt(s) }
    }

    /// Logo des Senders laden (auf weißem Grund, wie ein App-Cover) – danach Anzeige aktualisieren
    private func loadArt(_ s: RadioStation) {
        guard let l = s.favicon ?? logos[s.id], let url = URL(string: l) else {
            artCache[s.id] = Self.initialsArt(s)
            return
        }
        Task {
            guard let (d, _) = try? await URLSession.shared.data(from: url), let logo = UIImage(data: d) else {
                artCache[s.id] = Self.initialsArt(s); return
            }
            let size = CGSize(width: 600, height: 600)
            let img = UIGraphicsImageRenderer(size: size).image { _ in
                UIColor.white.setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
                let inset: CGFloat = 70
                let box = CGRect(x: inset, y: inset, width: size.width - 2 * inset, height: size.height - 2 * inset)
                let r = min(box.width / logo.size.width, box.height / logo.size.height)
                let w = logo.size.width * r, h = logo.size.height * r
                logo.draw(in: CGRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h))
            }
            artCache[s.id] = img
            if current?.id == s.id { updateNowPlaying() }
        }
    }

    /// Farbiges Kürzel als Cover („B3“, „DLF“), wenn es kein Logo gibt
    static func initialsArt(_ s: RadioStation) -> UIImage? {
        let size = CGSize(width: 600, height: 600)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor(Color(hex: s.color)).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let text = s.initials as NSString
            let font = UIFont.systemFont(ofSize: s.initials.count > 3 ? 150 : 210, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let t = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: (size.width - t.width) / 2, y: (size.height - t.height) / 2), withAttributes: attrs)
        }
    }

    private func setupRemote() {
        guard !remoteReady else { return }
        remoteReady = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { _ in Task { @MainActor in RadioPlayer.shared.resume() }; return .success }
        c.pauseCommand.addTarget { _ in Task { @MainActor in RadioPlayer.shared.pause() }; return .success }
        c.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in
                let p = RadioPlayer.shared
                if p.playing { p.pause() } else { p.resume() }
            }
            return .success
        }
        c.nextTrackCommand.addTarget { _ in Task { @MainActor in RadioPlayer.shared.next(1) }; return .success }
        c.previousTrackCommand.addTarget { _ in Task { @MainActor in RadioPlayer.shared.next(-1) }; return .success }
    }
}

// MARK: Bucket

enum RadioBucket {
    static let kind = BucketKind(
        id: "radio", name: "Radio", symbol: "radio.fill", tint: .red, art: .glance,
        interests: ["freizeit"], blurb: "Radio hören: Bayern 3, Antenne Bayern, Gong FM, Deutschlandfunk und mehr – mit Schlaf-Timer und AirPlay.",
        sizes: [.s, .m, .l], defaultSize: .m,
        glance: { inst, _ in AnyView(RadioGlance(bucketId: inst.id)) },
        detail: { inst in AnyView(RadioView(bucketId: inst.id)) },
        itemLinks: true
    )
}

/// Sender-Symbol: Logo aus dem Verzeichnis, sonst farbiges Kürzel
struct StationIcon: View {
    let station: RadioStation
    var size: CGFloat = 44
    @ObservedObject private var player = RadioPlayer.shared

    var body: some View {
        let logo = station.favicon ?? player.logos[station.id]
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(Color(hex: station.color))
            Text(station.initials).font(.system(size: size * (station.initials.count > 3 ? 0.26 : 0.34), weight: .bold))
                .foregroundColor(.white).minimumScaleFactor(0.5).lineLimit(1).padding(4)
            if let l = logo, let url = URL(string: l) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFit().padding(size * 0.1)
                            .background(Color.white)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Kleine Wellen-Anzeige „läuft gerade“
struct PlayingBars: View {
    var on: Bool
    @State private var phase = false
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(Theme.accent)
                    .frame(width: 3, height: on ? (phase ? [10, 5, 8][i] : [4, 10, 6][i]) : 4)
            }
        }
        .frame(height: 10)
        .animation(on ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true) : .default, value: phase)
        .onAppear { phase.toggle() }
    }
}

// MARK: Karte

struct RadioGlance: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @ObservedObject private var player = RadioPlayer.shared
    @Environment(\.glanceSpace) private var space
    @Environment(\.openBucketDetail) private var openDetail

    private var stations: [RadioStation] { RadioStation.list(store.buckets.first { $0.id == bucketId }?.config ?? [:]) }

    var body: some View {
        let list = stations
        VStack(alignment: .leading, spacing: 12) {
            if let s = player.current {
                nowPlaying(s, list)
            }
            // Sender zum Antippen – so viele, wie Platz ist
            let cols = max(2, Int(space.width / 72))
            let rows = player.current == nil ? (space.height > 200 ? 3 : 2) : (space.height > 220 ? 2 : 1)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: cols), spacing: 10) {
                ForEach(list.prefix(cols * rows)) { s in
                    Button { player.toggle(s, in: list) } label: {
                        VStack(spacing: 4) {
                            StationIcon(station: s, size: 46)
                                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(player.isCurrent(s) ? Theme.accent : .clear, lineWidth: 2.5))
                            Text(s.name).font(.caption2).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(s.name + (player.isCurrent(s) && player.playing ? ", läuft" : ""))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func nowPlaying(_ s: RadioStation, _ list: [RadioStation]) -> some View {
        HStack(spacing: 12) {
            StationIcon(station: s, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(s.name).font(.headline).lineLimit(1)
                    if player.playing && !player.loading { PlayingBars(on: true) }
                }
                Text(player.failed ?? (player.loading ? "Verbinde …" : player.song ?? (player.playing ? "Live" : "Pausiert")))
                    .font(.subheadline).foregroundColor(player.failed == nil ? Theme.secondary : .red).lineLimit(1)
            }
            Spacer(minLength: 6)
            Button { player.playing ? player.pause() : player.resume() } label: {
                Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.title3)
                    .foregroundColor(.white).frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.playing ? "Pause" : "Abspielen")
            Button { player.next() } label: {
                Image(systemName: "forward.fill").font(.body).foregroundColor(Theme.accent).frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nächster Sender")
        }
        .contentShape(Rectangle())
        .onTapGesture { openDetail() }
    }
}

// MARK: App

struct RadioView: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @ObservedObject private var player = RadioPlayer.shared
    @State private var adding = false

    private var stations: [RadioStation] { RadioStation.list(store.buckets.first { $0.id == bucketId }?.config ?? [:]) }

    var body: some View {
        let list = stations
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                nowPlayingCard(list)
                Text("SENDER").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(list) { s in
                        Button { player.toggle(s, in: list) } label: { stationTile(s) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { remove(s) } label: { Label("Entfernen", systemImage: "trash") }
                            }
                    }
                    Button { adding = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus").font(.title3.weight(.semibold)).foregroundColor(Theme.accent)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.accent.opacity(0.14)))
                            Text("Sender hinzufügen").font(.subheadline.weight(.semibold)).foregroundColor(Theme.accent)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                    }
                    .buttonStyle(.plain)
                }
                Text("Gedrückt halten zum Entfernen. Die Senderliste gilt im ganzen Haushalt.")
                    .font(.footnote).foregroundColor(Theme.secondary)
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $adding) { RadioSearchSheet { add($0) } }
    }

    private func nowPlayingCard(_ list: [RadioStation]) -> some View {
        VStack(spacing: 14) {
            if let s = player.current {
                HStack(spacing: 14) {
                    StationIcon(station: s, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(s.name).font(.title3.weight(.bold)).lineLimit(1)
                            if player.playing && !player.loading { PlayingBars(on: true) }
                        }
                        Text(player.failed ?? (player.loading ? "Verbinde …" : player.song ?? (player.playing ? "Live" : "Pausiert")))
                            .font(.subheadline).foregroundColor(player.failed == nil ? Theme.secondary : .red).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 28) {
                    Button { player.next(-1) } label: { Image(systemName: "backward.fill").font(.title2) }
                        .accessibilityLabel("Vorheriger Sender")
                    Button { player.playing ? player.pause() : player.resume() } label: {
                        Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.title).foregroundColor(.white)
                            .frame(width: 64, height: 64).background(Circle().fill(Theme.accent))
                    }
                    .accessibilityLabel(player.playing ? "Pause" : "Abspielen")
                    Button { player.next(1) } label: { Image(systemName: "forward.fill").font(.title2) }
                        .accessibilityLabel("Nächster Sender")
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.accent)
                HStack {
                    Menu {
                        Button("Aus") { player.setSleep(nil) }
                        ForEach([15, 30, 45, 60, 90], id: \.self) { m in Button("\(m) Minuten") { player.setSleep(m) } }
                    } label: {
                        Label(player.sleepAt.map { "Aus um " + Self.time.string(from: $0) } ?? "Schlaf-Timer", systemImage: "moon.zzz")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    AirPlayButton().frame(width: 36, height: 36).accessibilityLabel("AirPlay")
                    Button { player.stop() } label: { Label("Aus", systemImage: "stop.fill").font(.subheadline.weight(.semibold)) }
                        .buttonStyle(.borderless)
                }
                .foregroundColor(Theme.accent)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "radio").font(.title).foregroundColor(Theme.accent)
                    Text("Tippe auf einen Sender, um ihn einzuschalten.").foregroundColor(Theme.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    private func stationTile(_ s: RadioStation) -> some View {
        let on = player.isCurrent(s)
        return HStack(spacing: 10) {
            StationIcon(station: s, size: 44)
            Text(s.name).font(.subheadline.weight(.semibold)).foregroundColor(.primary).lineLimit(2)
            Spacer(minLength: 0)
            if on && player.playing { PlayingBars(on: !player.loading) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? Theme.accent : .clear, lineWidth: 2))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(s.name + (on && player.playing ? ", läuft" : ""))
    }

    private static let time: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()

    private func add(_ s: RadioStation) {
        store.updateConfig(bucketId) { c in
            var l = RadioStation.list(c)
            if !l.contains(where: { $0.id == s.id }) { l.append(s) }
            RadioStation.store(l, in: &c)
        }
    }

    private func remove(_ s: RadioStation) {
        if player.isCurrent(s) { player.stop() }
        store.updateConfig(bucketId) { c in
            var l = RadioStation.list(c)
            l.removeAll { $0.id == s.id }
            RadioStation.store(l, in: &c)
        }
    }
}

/// AirPlay-Auswahl (Lautsprecher, HomePod, Fernseher)
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.tintColor = UIColor(Theme.accent)
        v.activeTintColor = UIColor(Theme.accent)
        return v
    }
    func updateUIView(_ v: AVRoutePickerView, context: Context) {}
}

/// Sender suchen (radio-browser.info) und hinzufügen
struct RadioSearchSheet: View {
    let onAdd: (RadioStation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var hits: [RadioDirectory.Hit] = []
    @State private var searching = false
    @State private var added: Set<String> = []

    var body: some View {
        NavigationView {
            List {
                if searching { HStack { Spacer(); ProgressView(); Spacer() } }
                ForEach(hits) { h in
                    Button {
                        onAdd(RadioStation(id: h.stationuuid, name: h.name.trimmingCharacters(in: .whitespaces), url: h.url_resolved,
                                           favicon: h.favicon.flatMap { $0.isEmpty ? nil : $0 }, color: "8E8E93"))
                        added.insert(h.stationuuid)
                    } label: {
                        HStack(spacing: 12) {
                            StationIcon(station: RadioStation(id: h.stationuuid, name: h.name, favicon: h.favicon.flatMap { $0.isEmpty ? nil : $0 }, color: "8E8E93"), size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.name).foregroundColor(.primary).lineLimit(1)
                                Text([h.country, h.bitrate.map { "\($0) kbit/s" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: added.contains(h.stationuuid) ? "checkmark.circle.fill" : "plus.circle")
                                .font(.title3).foregroundColor(Theme.accent)
                        }
                        .frame(minHeight: 44)
                    }
                    .disabled(added.contains(h.stationuuid))
                }
                if !searching && hits.isEmpty && !query.isEmpty {
                    Text("Nichts gefunden – versuch einen anderen Namen.").foregroundColor(Theme.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Sender suchen, z. B. Radio Gong")
            .onSubmit(of: .search) { Task { await run() } }
            .task(id: query) {
                try? await Task.sleep(nanoseconds: 450_000_000)     // kurz warten, bis fertig getippt ist
                await run()
            }
            .navigationTitle("Sender hinzufügen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }

    private func run() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { hits = []; return }
        searching = true
        let r = await RadioDirectory.search(q)
        if q == query.trimmingCharacters(in: .whitespaces) { hits = r }
        searching = false
    }
}
