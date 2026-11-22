import SwiftUI
import Combine

// ============================================================
// Film & Serien (Daten: TMDB über die Server-Funktion „filme“)
//  - Beim Hinzufügen: eigene Streamingdienste wählen → alles darauf zugeschnitten
//  - Karte: Poster-Reihe „Neu diese Woche“ – gefolgte Serien mit neuer Folge zuerst
//  - Detail: Streaming · Serien · Kino · Meine (gefolgte Serien + Merkliste)
//  - Serien folgen (z. B. Dexter): nächste Folge mit Datum
//  - Zufall „Was schauen wir heute?“ mit Filtern (Art, Genres raus, Bewertung, Länge, nur Merkliste)
// Alles gilt für den eigenen Account (Bucket-Einstellungen), auf allen eigenen Geräten.
// Einstellungen: providers, kino/stream/tv, hide, follow, watch, rnd
// ============================================================

enum FilmBucket {
    static let kind = BucketKind(
        id: "filme", name: "Film & Serien", symbol: "film.stack", tint: .indigo, art: .glance,
        interests: ["freizeit"], blurb: "Neu auf deinen Streamingdiensten und im Kino, deine Serien – und ein Würfel für den Filmabend.",
        defaultConfig: ["kino": .bool(true), "stream": .bool(true), "tv": .bool(true)],
        needsSetup: { providers($0).isEmpty },
        glance: { inst, _ in AnyView(FilmGlance(instance: inst)) },
        detail: { inst in AnyView(FilmDetail(bucketId: inst.id)) },
        itemLinks: true,
        settings: { binding in AnyView(FilmSettings(config: binding)) }
    )

    static func providers(_ c: [String: JSON]) -> [Int] { (c["providers"]?.array ?? []).compactMap { $0.double.map { Int($0) } } }
    static func hidden(_ c: [String: JSON]) -> [Int] { (c["hide"]?.array ?? []).compactMap { $0.double.map { Int($0) } } }
    static func on(_ c: [String: JSON], _ key: String) -> Bool { c[key]?.bool ?? true }

    /// Gemerkte Einträge (Serien folgen / Merkliste) als kleine Objekte im Bucket
    struct Saved: Hashable, Identifiable {
        let id: Int; let t: String; let title: String; let poster: String?
        var key: String { t + "\(id)" }
        var json: JSON { .object(["id": .number(Double(id)), "t": .string(t), "title": .string(title), "poster": poster.map { .string($0) } ?? .null]) }
        init(id: Int, t: String, title: String, poster: String?) { self.id = id; self.t = t; self.title = title; self.poster = poster }
        init?(_ j: JSON) {
            guard let o = j.object, let id = o["id"]?.double, let title = o["title"]?.string else { return nil }
            self.init(id: Int(id), t: o["t"]?.string ?? "tv", title: title, poster: o["poster"]?.string)
        }
    }
    static func follow(_ c: [String: JSON]) -> [Saved] { (c["follow"]?.array ?? []).compactMap(Saved.init) }
    static func watch(_ c: [String: JSON]) -> [Saved] { (c["watch"]?.array ?? []).compactMap(Saved.init) }

    /// Eintrag in Liste „follow“ oder „watch“ an- oder abhaken
    static func toggle(_ list: String, _ s: Saved, in c: inout [String: JSON]) {
        var l = (c[list]?.array ?? []).compactMap(Saved.init)
        if let i = l.firstIndex(where: { $0.key == s.key }) { l.remove(at: i) } else { l.insert(s, at: 0) }
        c[list] = .array(l.map(\.json))
    }

    /// Zufalls-Filter (gemerkt)
    struct RandomFilter: Equatable {
        var type = "any"          // any, movie, tv
        var exclude: [Int] = []
        var minRating = 0.0
        var maxLength = 0         // Minuten, 0 = egal
        var fromList = false
        init() {}
        init(_ c: [String: JSON]) {
            guard let o = c["rnd"]?.object else { return }
            type = o["t"]?.string ?? "any"
            exclude = (o["x"]?.array ?? []).compactMap { $0.double.map { Int($0) } }
            minRating = o["min"]?.double ?? 0
            maxLength = Int(o["len"]?.double ?? 0)
            fromList = o["list"]?.bool ?? false
        }
        var json: JSON {
            .object(["t": .string(type), "x": .array(exclude.map { .number(Double($0)) }), "min": .number(minRating),
                     "len": .number(Double(maxLength)), "list": .bool(fromList)])
        }
    }
}

// MARK: Daten

struct FilmProvider: Codable, Identifiable, Hashable { let id: Int; let name: String; let logo: String? }
struct FilmEpisode: Codable, Hashable { let s: Int; let e: Int; let date: String?; let name: String? }
struct FilmItem: Codable, Hashable {
    let id: Int; let t: String; let title: String; let poster: String?; let date: String?
    let rating: Double?; let genres: [Int]?; let providers: [FilmProvider]?; let next: FilmEpisode?; let kino: Bool?
    var key: String { t + "\(id)" }
    var saved: FilmBucket.Saved { .init(id: id, t: t, title: title, poster: poster) }
}
struct FilmFeed: Codable { let kino: [FilmItem]; let stream: [FilmItem]; let tv: [FilmItem] }
struct FilmTitle: Codable {
    let id: Int; let t: String; let title: String; let original: String?; let overview: String?
    let poster: String?; let backdrop: String?; let date: String?; let runtime: Int?; let genres: [String]?
    let rating: Double?; let votes: Int?; let fsk: String?; let providers: [FilmProvider]?
    let seasons: Int?; let ended: Bool?; let next: FilmEpisode?; let last: FilmEpisode?; let networks: [String]?
    var saved: FilmBucket.Saved { .init(id: id, t: t, title: title, poster: poster) }
}
struct FilmShow: Codable {
    let id: Int; let title: String; let poster: String?; let providers: [FilmProvider]?
    let ended: Bool?; let seasons: Int?; let next: FilmEpisode?; let last: FilmEpisode?
}
struct FilmGenre: Codable, Identifiable, Hashable { let id: Int; let name: String }

/// Ein Titel zum Öffnen (Blatt)
struct FilmRef: Identifiable, Hashable { let id: Int; let t: String; var key: String { t + "\(id)" } }

final class FilmService: ObservableObject {
    static let shared = FilmService()
    @Published private(set) var providers: [FilmProvider] = []
    @Published private(set) var genres: [FilmGenre] = []
    @Published private(set) var feeds: [String: FilmFeed] = [:]
    @Published private(set) var shows: [Int: FilmShow] = [:]
    @Published private(set) var failed = false
    private var loadedAt: [String: Date] = [:]

    func get<T: Decodable>(_ route: String, _ q: [(String, String)] = [], _ type: T.Type) async throws -> T {
        let data = try await SupabaseClient.shared.raw("GET", "/functions/v1/filme/" + route,
                                                       query: q.map { URLQueryItem(name: $0.0, value: $0.1) })
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func feedKey(_ c: [String: JSON]) -> String {
        FilmBucket.providers(c).map(String.init).joined(separator: ",") + "|" + FilmBucket.hidden(c).map(String.init).joined(separator: ",")
    }

    func loadBasics() async {
        if providers.isEmpty, let p = try? await get("providers", [], [FilmProvider].self) { providers = p }
        if genres.isEmpty, let g = try? await get("genres", [], [FilmGenre].self) { genres = g }
    }

    func loadFeed(_ c: [String: JSON], force: Bool = false) async {
        let k = Self.feedKey(c)
        if !force, let t = loadedAt[k], Date().timeIntervalSince(t) < 3 * 3600 { return }
        do {
            let f = try await get("feed", [("p", FilmBucket.providers(c).map(String.init).joined(separator: ",")),
                                          ("x", FilmBucket.hidden(c).map(String.init).joined(separator: ","))], FilmFeed.self)
            feeds[k] = f; loadedAt[k] = Date(); failed = false
        } catch { if feeds[k] == nil { failed = true }; print("Filme:", error) }
    }

    func loadShows(_ ids: [Int], force: Bool = false) async {
        guard !ids.isEmpty else { return }
        let k = "shows:" + ids.map(String.init).joined(separator: ",")
        if !force, let t = loadedAt[k], Date().timeIntervalSince(t) < 3 * 3600 { return }
        if let list = try? await get("shows", [("ids", ids.map(String.init).joined(separator: ","))], [FilmShow].self) {
            for s in list { shows[s.id] = s }
            loadedAt[k] = Date()
        }
    }

    func title(_ r: FilmRef) async -> FilmTitle? { try? await get("title", [("t", r.t), ("id", String(r.id))], FilmTitle.self) }
    func search(_ q: String, tvOnly: Bool) async -> [FilmItem] {
        (try? await get("search", [("q", q), ("t", tvOnly ? "tv" : "multi")], [FilmItem].self)) ?? []
    }
    func random(_ f: FilmBucket.RandomFilter, providers: [Int]) async -> FilmTitle? {
        try? await get("random", [("t", f.type), ("p", providers.map(String.init).joined(separator: ",")),
                                  ("x", f.exclude.map(String.init).joined(separator: ",")),
                                  ("min", String(f.minRating)), ("len", String(f.maxLength))], FilmTitle.self)
    }
}

enum FilmFmt {
    static let ymd: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f }()
    static func date(_ s: String?) -> Date? { s.flatMap { ymd.date(from: String($0.prefix(10))) } }
    static func days(_ s: String?) -> Int? {
        guard let d = date(s) else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: d).day
    }
    /// „Heute“, „Morgen“, „Fr“, „Do 4.12.“, „neu“, „20.11.“
    static func when(_ s: String?, past: String = "neu") -> String {
        guard let d = date(s), let n = days(s) else { return "" }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE")
        switch n {
        case 0: return "Heute"
        case 1: return "Morgen"
        case 2...6: f.dateFormat = "EEEE"; return f.string(from: d)
        case 7...: f.dateFormat = "EE d.M."; return f.string(from: d).replacingOccurrences(of: ".,", with: "")
        case -7 ... -1: return past
        default: f.dateFormat = "d.M.yyyy"; return f.string(from: d)
        }
    }
    static func episode(_ e: FilmEpisode) -> String { "S\(e.s) E\(e.e)" }
    static func rating(_ r: Double?) -> String? {
        guard let r = r, r > 0 else { return nil }
        return String(format: "%.1f", r).replacingOccurrences(of: ".", with: ",")
    }
    static func runtime(_ m: Int?) -> String? {
        guard let m = m, m > 0 else { return nil }
        return m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
    }
}

// MARK: Bausteine

struct FilmPoster: View {
    let url: String?
    var width: CGFloat = 96
    var body: some View {
        AsyncImage(url: url.flatMap(URL.init)) { img in img.resizable().scaledToFill() } placeholder: {
            ZStack { Color(UIColor.tertiarySystemFill); Image(systemName: "film").foregroundColor(Theme.secondary) }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ProviderLogo: View {
    let p: FilmProvider
    var size: CGFloat = 20
    var body: some View {
        AsyncImage(url: p.logo.flatMap(URL.init)) { img in img.resizable().scaledToFit() } placeholder: { Color(UIColor.tertiarySystemFill) }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityLabel(p.name)
    }
}

/// Ein Eintrag der Poster-Reihe
struct FilmTile: View {
    let item: FilmItem
    let mine: Set<Int>
    var width: CGFloat = 96
    var badge: String? = nil        // z. B. „⭐ S2 E4“
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FilmPoster(url: item.poster, width: width)
                .overlay(alignment: .topLeading) {
                    if let b = badge {
                        Text(b).font(.caption2.weight(.bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.accent)).padding(5)
                    }
                }
            Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
            HStack(spacing: 4) {
                if item.kino == true { Image(systemName: "popcorn").font(.caption2).foregroundColor(Theme.secondary) }
                else if let p = (item.providers ?? []).first(where: { mine.contains($0.id) }) ?? item.providers?.first { ProviderLogo(p: p, size: 14) }
                Text(item.next.map { FilmFmt.episode($0) + " · " + FilmFmt.when($0.date, past: "neu") } ?? FilmFmt.when(item.date, past: "neu"))
                    .font(.caption2).foregroundColor(Theme.secondary).lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: Karte

struct FilmGlance: View {
    let instance: BucketInstance
    @EnvironmentObject var store: AppStore
    @ObservedObject private var service = FilmService.shared
    @Environment(\.glanceSpace) private var space
    @Environment(\.editBucket) private var editBucket
    @State private var open: FilmRef?

    var body: some View {
        let c = instance.config
        Group {
            if FilmBucket.providers(c).isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Wähle deine Streamingdienste – dann zeigt Hubert, was dort neu ist.").foregroundColor(Theme.secondary)
                    Button("Dienste wählen") { editBucket() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                }
            } else if let feed = service.feeds[FilmService.feedKey(c)] {
                content(c, feed)
            } else if service.failed {
                Text("Gerade keine Daten – versuche es gleich nochmal").foregroundColor(Theme.secondary)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: FilmService.feedKey(c)) {
            guard !FilmBucket.providers(c).isEmpty else { return }
            await service.loadFeed(c)
            await service.loadShows(FilmBucket.follow(c).map(\.id))
        }
        .sheet(item: $open) { FilmTitleSheet(ref: $0, bucketId: instance.id).environmentObject(store) }
    }

    /// Ein Eintrag der Karte; star = gefolgte Serie mit neuer Folge
    private struct Entry: Identifiable { let item: FilmItem; let star: Bool; var id: String { item.key } }

    /// Gefolgte Serien mit Folge in den nächsten 7 Tagen (oder heute) zuerst, dann Neues gemischt
    private func items(_ c: [String: JSON], _ f: FilmFeed) -> [Entry] {
        var out: [Entry] = []
        var seen = Set<String>()
        for s in FilmBucket.follow(c) {
            guard let sh = service.shows[s.id], let n = sh.next, let d = FilmFmt.days(n.date), d >= 0, d <= 7 else { continue }
            let it = FilmItem(id: sh.id, t: "tv", title: sh.title, poster: sh.poster, date: n.date, rating: nil, genres: nil,
                              providers: sh.providers, next: n, kino: nil)
            out.append(Entry(item: it, star: true)); seen.insert(it.key)
        }
        let lists = [FilmBucket.on(c, "stream") ? f.stream : [], FilmBucket.on(c, "tv") ? f.tv : [], FilmBucket.on(c, "kino") ? f.kino : []]
        for i in 0..<20 {
            for l in lists where i < l.count && !seen.contains(l[i].key) { out.append(Entry(item: l[i], star: false)); seen.insert(l[i].key) }
        }
        return out
    }

    @ViewBuilder private func content(_ c: [String: JSON], _ f: FilmFeed) -> some View {
        let list = items(c, f)
        let mine = Set(FilmBucket.providers(c))
        if list.isEmpty {
            Text("Diese Woche nichts Neues auf deinen Diensten").foregroundColor(Theme.secondary)
        } else if space.height >= 150 {
            // Poster-Reihe, so hoch wie die Karte es zulässt
            let w = min(120, max(72, (space.height - 44) / 1.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(list) { e in
                        Button { open = FilmRef(id: e.item.id, t: e.item.t) } label: {
                            FilmTile(item: e.item, mine: mine, width: w, badge: e.star ? "⭐ " + (e.item.next.map(FilmFmt.episode) ?? "") : nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            // Wenig Platz: Textzeilen
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(list.prefix(fitRows(space.height, row: 26)))) { e in
                    let it = e.item
                    Button { open = FilmRef(id: it.id, t: it.t) } label: {
                        HStack(spacing: 8) {
                            if e.star { Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption) }
                            else { Image(systemName: it.kino == true ? "popcorn" : it.t == "tv" ? "tv" : "film").font(.caption).foregroundColor(Theme.secondary) }
                            Text(it.title).font(.subheadline).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(it.next.map { FilmFmt.episode($0) + " · " + FilmFmt.when($0.date) } ?? FilmFmt.when(it.date))
                                .font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: Detail

struct FilmDetail: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @ObservedObject private var service = FilmService.shared
    @State private var tab = "stream"
    @State private var open: FilmRef?
    @State private var dice = false
    @State private var adding = false

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        let c = config
        let feed = service.feeds[FilmService.feedKey(c)]
        let mine = Set(FilmBucket.providers(c))
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Würfel
                Button { dice = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "die.face.5.fill").font(.title2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Was schauen wir heute?").font(.headline)
                            Text("Zufälliger Film oder Serie von deinen Diensten").font(.caption).opacity(0.85)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).opacity(0.7)
                    }
                    .foregroundColor(.white).padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accent))
                }
                .buttonStyle(.plain)

                Picker("Bereich", selection: $tab) {
                    Text("Streaming").tag("stream"); Text("Serien").tag("tv"); Text("Kino").tag("kino"); Text("Meine").tag("mine")
                }
                .pickerStyle(.segmented)

                if tab == "mine" {
                    mineSection(c, mine)
                } else if let f = feed {
                    let list = tab == "stream" ? f.stream : tab == "tv" ? f.tv : f.kino
                    if list.isEmpty {
                        Text(tab == "kino" ? "Gerade keine Kinostarts" : "Diese Woche nichts Neues auf deinen Diensten")
                            .foregroundColor(Theme.secondary).frame(maxWidth: .infinity).padding(.vertical, 30)
                    } else {
                        Text(tab == "kino" ? "Kinostarts in Deutschland" : tab == "tv" ? "Neue Folgen auf deinen Diensten" : "Neu auf deinen Diensten")
                            .font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary).textCase(.uppercase)
                        grid(list, mine)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                }

                Text("Daten: TMDB. Dieses Produkt nutzt die TMDB-API, ist aber nicht von TMDB unterstützt oder zertifiziert.")
                    .font(.caption2).foregroundColor(Theme.secondary).padding(.top, 8)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Film & Serien")
        .task {
            await service.loadBasics()
            await service.loadFeed(c)
            await service.loadShows(FilmBucket.follow(c).map(\.id), force: true)
        }
        .refreshable {
            await service.loadFeed(c, force: true)
            await service.loadShows(FilmBucket.follow(c).map(\.id), force: true)
        }
        .sheet(item: $open) { FilmTitleSheet(ref: $0, bucketId: bucketId).environmentObject(store) }
        .sheet(isPresented: $dice) { FilmRandomSheet(bucketId: bucketId).environmentObject(store) }
        .sheet(isPresented: $adding) { FilmSearchSheet(bucketId: bucketId).environmentObject(store) }
    }

    private func grid(_ list: [FilmItem], _ mine: Set<Int>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 14, alignment: .top)], alignment: .leading, spacing: 18) {
            ForEach(list, id: \.key) { it in
                Button { open = FilmRef(id: it.id, t: it.t) } label: {
                    FilmTile(item: it, mine: mine, width: 100)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func mineSection(_ c: [String: JSON], _ mine: Set<Int>) -> some View {
        let follow = FilmBucket.follow(c)
        HStack {
            Text("Meine Serien").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary).textCase(.uppercase)
            Spacer()
            Button { adding = true } label: { Label("Serie hinzufügen", systemImage: "plus") }.font(.subheadline)
        }
        if follow.isEmpty {
            Text("Folge einer Serie (z. B. Dexter) – dann siehst du hier, wann die nächste Folge kommt.")
                .font(.subheadline).foregroundColor(Theme.secondary)
        } else {
            VStack(spacing: 0) {
                // Nächste Folge zuerst, Serien ohne Termin danach
                let sorted = follow.sorted { a, b in
                    (FilmFmt.days(service.shows[a.id]?.next?.date) ?? 9999) < (FilmFmt.days(service.shows[b.id]?.next?.date) ?? 9999)
                }
                ForEach(Array(sorted.enumerated()), id: \.element.key) { i, s in
                    if i > 0 { Divider().padding(.leading, 66) }
                    Button { open = FilmRef(id: s.id, t: "tv") } label: { showRow(s, mine) }.buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        }

        let watch = FilmBucket.watch(c)
        Text("Merkliste").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary).textCase(.uppercase).padding(.top, 6)
        if watch.isEmpty {
            Text("Tippe bei einem Film oder einer Serie auf „Merken“.").font(.subheadline).foregroundColor(Theme.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 14, alignment: .top)], alignment: .leading, spacing: 18) {
                ForEach(watch) { s in
                    Button { open = FilmRef(id: s.id, t: s.t) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            FilmPoster(url: s.poster, width: 100)
                            Text(s.title).font(.caption.weight(.semibold)).lineLimit(1)
                        }
                        .frame(width: 100, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func showRow(_ s: FilmBucket.Saved, _ mine: Set<Int>) -> some View {
        let sh = service.shows[s.id]
        var line = "Lädt …", tone = Theme.secondary
        if let sh = sh {
            if let n = sh.next {
                let d = FilmFmt.days(n.date) ?? 0
                line = FilmFmt.episode(n) + " · " + (d == 0 ? "heute" : d == 1 ? "morgen" : d < 0 ? FilmFmt.when(n.date) : "in \(d) Tagen, " + FilmFmt.when(n.date))
                if d <= 1 { tone = Theme.accent }
            } else if sh.ended == true { line = "Serie beendet" + (sh.seasons.map { " · \($0) Staffeln" } ?? "") }
            else { line = "Noch kein Termin für die nächste Folge" }
        }
        return HStack(spacing: 12) {
            FilmPoster(url: s.poster ?? sh?.poster, width: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.title).font(.body.weight(.semibold)).foregroundColor(.primary).lineLimit(1)
                Text(line).font(.subheadline).foregroundColor(tone).lineLimit(1)
            }
            Spacer(minLength: 6)
            if let p = (sh?.providers ?? []).first(where: { mine.contains($0.id) }) ?? sh?.providers?.first { ProviderLogo(p: p, size: 26) }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: Titel-Blatt

struct FilmTitleSheet: View {
    let ref: FilmRef
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title: FilmTitle?
    @State private var failed = false

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        NavigationView {
            Group {
                if let t = title { FilmTitleView(t: t, config: config, onToggle: toggle) }
                else if failed { Text("Gerade nicht erreichbar").foregroundColor(Theme.secondary) }
                else { ProgressView() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .task {
            title = await FilmService.shared.title(ref)
            failed = title == nil
        }
    }

    private func toggle(_ list: String, _ s: FilmBucket.Saved) {
        store.updateConfig(bucketId) { FilmBucket.toggle(list, s, in: &$0) }
        if list == "follow" { Task { await FilmService.shared.loadShows([s.id], force: true) } }
    }
}

/// Inhalt eines Titels – auch im Zufalls-Blatt verwendet
struct FilmTitleView: View {
    let t: FilmTitle
    let config: [String: JSON]
    let onToggle: (String, FilmBucket.Saved) -> Void

    var body: some View {
        let mine = Set(FilmBucket.providers(config))
        let watched = FilmBucket.watch(config).contains { $0.key == t.saved.key }
        let followed = FilmBucket.follow(config).contains { $0.id == t.id && t.t == "tv" }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hintergrundbild mit Poster
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: t.backdrop.flatMap(URL.init)) { img in img.resizable().scaledToFill() } placeholder: {
                        Color(UIColor.tertiarySystemFill)
                    }
                    .frame(height: 200).frame(maxWidth: .infinity).clipped()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom))
                    HStack(alignment: .bottom, spacing: 14) {
                        FilmPoster(url: t.poster, width: 84).shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t.title).font(.title2.weight(.bold)).foregroundColor(.white).lineLimit(2).minimumScaleFactor(0.8)
                            Text(meta).font(.subheadline).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                        }
                    }
                    .padding(14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Merken / Folgen
                HStack(spacing: 10) {
                    actionButton(watched ? "Gemerkt" : "Merken", watched ? "star.fill" : "star", on: watched) { onToggle("watch", t.saved) }
                    if t.t == "tv" {
                        actionButton(followed ? "Gefolgt" : "Folgen", followed ? "bell.fill" : "bell", on: followed) { onToggle("follow", t.saved) }
                    }
                }

                if t.t == "tv" { episodeCard }

                if let g = t.genres, !g.isEmpty {
                    Text(g.joined(separator: " · ")).font(.subheadline).foregroundColor(Theme.secondary)
                }
                if let o = t.overview { Text(o).font(.body) }

                // Wo läuft es?
                VStack(alignment: .leading, spacing: 8) {
                    Text("Läuft bei").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary).textCase(.uppercase)
                    let ps = (t.providers ?? []).sorted { mine.contains($0.id) && !mine.contains($1.id) }
                    if ps.isEmpty {
                        Text(t.t == "movie" && (FilmFmt.days(t.date) ?? -999) > -60 ? "Noch nicht im Streaming – im Kino" : "Gerade bei keinem Abo-Dienst")
                            .font(.subheadline).foregroundColor(Theme.secondary)
                    } else {
                        ForEach(ps) { p in
                            HStack(spacing: 10) {
                                ProviderLogo(p: p, size: 30)
                                Text(p.name)
                                Spacer()
                                if mine.contains(p.id) { Text("Hast du").font(.caption.weight(.semibold)).foregroundColor(Theme.accent) }
                            }
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))

                Text("Daten: TMDB").font(.caption2).foregroundColor(Theme.secondary)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var meta: String {
        var parts: [String] = []
        if let y = t.date?.prefix(4), !y.isEmpty { parts.append(String(y)) }
        if t.t == "tv", let s = t.seasons { parts.append(s == 1 ? "1 Staffel" : "\(s) Staffeln") }
        if let r = FilmFmt.runtime(t.runtime) { parts.append(r) }
        if let f = t.fsk { parts.append("FSK " + f) }
        if let r = FilmFmt.rating(t.rating) { parts.append("★ " + r) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var episodeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let n = t.next {
                Text("Nächste Folge").font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                Text(FilmFmt.episode(n) + (n.name.map { " · „" + $0 + "“" } ?? "")).font(.headline)
                Text(nextWhen(n)).font(.subheadline).foregroundColor(Theme.accent)
            } else if t.ended == true {
                Text("Serie beendet").font(.headline)
                if let l = t.last { Text("Letzte Folge: " + FilmFmt.episode(l) + (l.date.flatMap { FilmFmt.date($0) }.map { " · " + $0.formatted(.dateTime.day().month().year()) } ?? "")).font(.subheadline).foregroundColor(Theme.secondary) }
            } else {
                Text("Noch kein Termin für die nächste Folge").font(.headline)
                if let l = t.last { Text("Zuletzt: " + FilmFmt.episode(l)).font(.subheadline).foregroundColor(Theme.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }

    private func nextWhen(_ n: FilmEpisode) -> String {
        guard let d = FilmFmt.days(n.date), let date = FilmFmt.date(n.date) else { return "Datum noch offen" }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEEE, d. MMMM"
        let s = f.string(from: date)
        return d == 0 ? "Heute · " + s : d == 1 ? "Morgen · " + s : d > 1 ? "In \(d) Tagen · " + s : s
    }

    private func actionButton(_ title: String, _ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.body.weight(.semibold))
                .foregroundColor(on ? .white : Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Theme.accent : Color(UIColor.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Zufall

struct FilmRandomSheet: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = FilmService.shared
    @State private var filter = FilmBucket.RandomFilter()
    @State private var result: FilmTitle?
    @State private var rolling = false
    @State private var empty = false
    @State private var showFilter = true

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let r = result, !showFilter {
                    FilmTitleView(t: r, config: config) { list, s in store.updateConfig(bucketId) { FilmBucket.toggle(list, s, in: &$0) } }
                } else {
                    filterForm
                }
                // Würfeln
                HStack(spacing: 10) {
                    if result != nil {
                        Button { withAnimation { showFilter.toggle() } } label: {
                            Image(systemName: showFilter ? "film" : "slider.horizontal.3").font(.body.weight(.semibold))
                                .frame(width: 52, height: 52)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                        }
                        .accessibilityLabel(showFilter ? "Vorschlag zeigen" : "Filter")
                    }
                    Button { Task { await roll() } } label: {
                        HStack(spacing: 8) {
                            if rolling { ProgressView().tint(.white) } else { Image(systemName: "die.face.5.fill") }
                            Text(result == nil ? "Würfeln" : "Nochmal würfeln").font(.headline)
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
                    }
                    .disabled(rolling)
                }
                .padding(16)
                .background(.regularMaterial)
            }
            .navigationTitle("Was schauen wir heute?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .onAppear { filter = FilmBucket.RandomFilter(config) }
        .task { await service.loadBasics() }
    }

    private var filterForm: some View {
        Form {
            Section("Was") {
                Picker("Art", selection: $filter.type) {
                    Text("Egal").tag("any"); Text("Film").tag("movie"); Text("Serie").tag("tv")
                }
                .pickerStyle(.segmented)
                Toggle("Nur aus meiner Merkliste", isOn: $filter.fromList).tint(Theme.accent)
            }
            Section("Bewertung") {
                Picker("Mindestens", selection: $filter.minRating) {
                    Text("Egal").tag(0.0); Text("ab 6").tag(6.0); Text("ab 7").tag(7.0); Text("ab 8").tag(8.0)
                }
                .pickerStyle(.segmented)
            }
            if filter.type != "tv" {
                Section("Länge (Filme)") {
                    Picker("Höchstens", selection: $filter.maxLength) {
                        Text("Egal").tag(0); Text("< 1,5 h").tag(90); Text("< 2 h").tag(120); Text("< 2,5 h").tag(150)
                    }
                    .pickerStyle(.segmented)
                }
            }
            Section {
                GenreChips(genres: service.genres, selected: $filter.exclude, crossed: true)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            } header: { Text("Diese Genres nicht") } footer: {
                Text(empty ? "Nichts gefunden – lockere die Filter etwas." : "Hubert schlägt nur vor, was auf deinen Diensten läuft.")
            }
        }
    }

    private func roll() async {
        rolling = true; empty = false
        store.updateConfig(bucketId) { $0["rnd"] = filter.json }   // Filter merken
        var pick: FilmTitle?
        if filter.fromList {
            let pool = FilmBucket.watch(config).filter { filter.type == "any" || $0.t == filter.type }
            if let s = pool.randomElement() { pick = await service.title(FilmRef(id: s.id, t: s.t)) }
        } else {
            pick = await service.random(filter, providers: FilmBucket.providers(config))
        }
        if let p = pick { withAnimation { result = p; showFilter = false } } else { empty = true; showFilter = true }
        rolling = false
    }
}

/// Genre-Kapseln zum An-/Abwählen (durchgestrichen = ausgeschlossen)
struct GenreChips: View {
    let genres: [FilmGenre]
    @Binding var selected: [Int]
    var crossed = false

    var body: some View {
        if genres.isEmpty {
            HStack(spacing: 8) { ProgressView(); Text("Lädt Genres …").foregroundColor(Theme.secondary) }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(genres) { g in
                    let on = selected.contains(g.id)
                    Button {
                        if let i = selected.firstIndex(of: g.id) { selected.remove(at: i) } else { selected.append(g.id) }
                    } label: {
                        Text(g.name).font(.subheadline.weight(on ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.75)
                            .strikethrough(on && crossed)
                            .foregroundColor(on ? .white : .primary)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(on ? (crossed ? Color(UIColor.systemGray) : Theme.accent) : Color(UIColor.tertiarySystemFill)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: Serie suchen

struct FilmSearchSheet: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [FilmItem] = []
    @State private var searching = false

    private var followed: Set<Int> { Set(FilmBucket.follow(store.buckets.first { $0.id == bucketId }?.config ?? [:]).map(\.id)) }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
                        TextField("Serie suchen, z. B. Dexter", text: $query).disableAutocorrection(true)
                        if searching { ProgressView() }
                    }
                }
                Section {
                    ForEach(results, id: \.key) { it in
                        let on = followed.contains(it.id)
                        Button {
                            store.updateConfig(bucketId) { FilmBucket.toggle("follow", it.saved, in: &$0) }
                            if !on { Task { await FilmService.shared.loadShows([it.id], force: true) } }
                        } label: {
                            HStack(spacing: 12) {
                                FilmPoster(url: it.poster, width: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(it.title).foregroundColor(.primary)
                                    if let y = it.date?.prefix(4), !y.isEmpty { Text("seit " + y).font(.caption).foregroundColor(Theme.secondary) }
                                }
                                Spacer()
                                Image(systemName: on ? "checkmark.circle.fill" : "plus.circle").font(.title3).foregroundColor(Theme.accent)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Serie folgen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard q.count >= 2 else { results = []; return }
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { return }
                searching = true
                let r = await FilmService.shared.search(q, tvOnly: true)
                if !Task.isCancelled { results = r }
                searching = false
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Einstellungen

struct FilmSettings: View {
    @Binding var config: [String: JSON]
    @ObservedObject private var service = FilmService.shared

    private var chosen: Binding<[Int]> {
        Binding(get: { FilmBucket.providers(config) }, set: { config["providers"] = .array($0.map { .number(Double($0)) }) })
    }
    private var hidden: Binding<[Int]> {
        Binding(get: { FilmBucket.hidden(config) }, set: { config["hide"] = .array($0.map { .number(Double($0)) }) })
    }
    private func flag(_ key: String) -> Binding<Bool> {
        Binding(get: { FilmBucket.on(config, key) }, set: { config[key] = .bool($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meine Streamingdienste").font(.subheadline.weight(.semibold))
            if service.providers.isEmpty {
                HStack(spacing: 8) { ProgressView(); Text("Lädt Dienste …").foregroundColor(Theme.secondary) }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 10)], spacing: 12) {
                    ForEach(service.providers) { p in
                        let on = chosen.wrappedValue.contains(p.id)
                        Button {
                            var l = chosen.wrappedValue
                            if let i = l.firstIndex(of: p.id) { l.remove(at: i) } else { l.append(p.id) }
                            chosen.wrappedValue = l
                        } label: {
                            VStack(spacing: 4) {
                                ProviderLogo(p: p, size: 46)
                                    .overlay(alignment: .topTrailing) {
                                        if on {
                                            Image(systemName: "checkmark.circle.fill").font(.body).foregroundColor(Theme.accent)
                                                .background(Circle().fill(Color.white)).offset(x: 6, y: -6)
                                        }
                                    }
                                    .opacity(on ? 1 : 0.55)
                                Text(p.name).font(.caption2).foregroundColor(on ? .primary : Theme.secondary).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(p.name + (on ? ", ausgewählt" : ""))
                    }
                }
            }
            Text("Hubert zeigt nur Filme und Serien, die du mit diesen Diensten schauen kannst.")
                .font(.caption).foregroundColor(Theme.secondary)
        }
        .padding(.vertical, 4)
        .task { await service.loadBasics() }

        Toggle("Streaming-Filme", isOn: flag("stream")).tint(Theme.accent)
        Toggle("Serien", isOn: flag("tv")).tint(Theme.accent)
        Toggle("Kinostarts", isOn: flag("kino")).tint(Theme.accent)

        VStack(alignment: .leading, spacing: 8) {
            Text("Genres ausblenden").font(.subheadline.weight(.semibold))
            GenreChips(genres: service.genres, selected: hidden, crossed: true)
        }
        .padding(.vertical, 4)

        Text("Daten: TMDB").font(.caption2).foregroundColor(Theme.secondary)
    }
}
