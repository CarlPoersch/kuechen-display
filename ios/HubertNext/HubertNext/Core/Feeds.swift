import SwiftUI
import Combine

// ============================================================
// Sport und News kommen über die Supabase-Funktion "feeds"
// (dieselbe Quelle wie in der Web-Version, angemeldet per Login).
// ============================================================

// MARK: Datum und Zeit

enum Fmt {
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let iso = ISO8601DateFormatter()
    private static let isoShort: DateFormatter = {   // ESPN: "2026-11-20T19:30Z"
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mmXXXXX"; return f
    }()
    private static let de = Locale(identifier: "de_DE")

    static func date(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        return isoFrac.date(from: s) ?? iso.date(from: s) ?? isoShort.date(from: s)
    }

    static func hhmm(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = de; f.dateFormat = "HH:mm"; return f.string(from: d)
    }

    static func dayDiff(_ d: Date) -> Int {
        let c = Calendar.current
        return c.dateComponents([.day], from: c.startOfDay(for: Date()), to: c.startOfDay(for: d)).day ?? 0
    }

    /// "20:30", "morgen 20:30", "gestern", "Di 18:45", "Mo 17.11."
    static func when(_ d: Date) -> String {
        let dd = dayDiff(d)
        if dd == 0 { return hhmm(d) }
        if dd == 1 { return "morgen " + hhmm(d) }
        if dd == -1 { return "gestern" }
        let f = DateFormatter(); f.locale = de; f.dateFormat = dd < 0 ? "EEEEEE d.M." : "EEEEEE HH:mm"
        return f.string(from: d)
    }

    /// "Heute", "Morgen", "Gestern", "Montag, 24.11."
    static func dayLabel(_ d: Date) -> String {
        switch dayDiff(d) {
        case 0: return "Heute"
        case 1: return "Morgen"
        case -1: return "Gestern"
        default:
            let f = DateFormatter(); f.locale = de; f.dateFormat = "EEEE, d.M."; return f.string(from: d)
        }
    }

    /// "vor 5 Min", "vor 2 Std", "Mo 14:20"
    static func ago(_ d: Date) -> String {
        let m = Int(Date().timeIntervalSince(d) / 60)
        if m < 1 { return "gerade eben" }
        if m < 60 { return "vor \(m) Min" }
        if m < 12 * 60 { return "vor \(m / 60) Std" }
        let f = DateFormatter(); f.locale = de; f.dateFormat = "EEEEEE HH:mm"; return f.string(from: d)
    }
}

// MARK: Modelle

struct SportFeed: Decodable { let matches: [Match] }

struct Match: Decodable, Identifiable {
    struct Side: Decodable {
        let n: String
        let c: String?
        let score: String?
        let win: Bool?
        let sets: [Double]?
        let tb: [Double?]?
        let r: Int?
        var flag: String { c == "GER" ? " 🇩🇪" : "" }
    }
    let id: String
    let sport: String          // "fb" Fußball, "tn" Tennis
    let comp: String
    let round: String?
    let date: String
    let state: String          // pre, in, post
    let detail: String
    let a: Side
    let b: Side
    let prio: Int              // 1 = Favorit
    let lg: String?
    let eid: String?
    let venue: String?
    let note: String?

    var start: Date { Fmt.date(date) ?? .distantPast }
    var isLive: Bool { state == "in" }
}

struct NewsFeed: Decodable {
    let breaking: [NewsItem]
    let de: [NewsItem]
    let welt: [NewsItem]
    let ki: [NewsItem]

    func list(_ topic: String) -> [NewsItem] { topic == "de" ? de : topic == "welt" ? welt : topic == "ki" ? ki : [] }
}

struct NewsItem: Decodable, Identifiable, Hashable {
    let t: String
    let top: String?
    let d: String
    let u: String
    let s: String?
    let b: Bool?
    let x: String?
    var id: String { u }
    /// Was die Funktion zum Laden des Artikels braucht (Tagesschau: API-Link, heise: Seite)
    var key: String { x ?? u }
    var date: Date { Fmt.date(d) ?? Date() }
}

struct Article: Decodable {
    struct Block: Decodable, Hashable { let k: String; let t: String }
    let t: String?
    let top: String?
    let d: String?
    let img: String?
    let blocks: [Block]
    let src: String?
    let plus: Bool?
}

struct MatchDetail: Decodable {
    struct Side: Decodable { let n: String; let score: String?; let win: Bool?; let ht: String? }
    struct Event: Decodable, Hashable { let min: String; let kind: String; let side: String; let who: String; let extra: String }
    struct Player: Decodable, Hashable { let n: String; let nr: String; let pos: String }
    struct Lineup: Decodable { let form: String; let xi: [Player]; let bench: [Player] }
    struct Lineups: Decodable { let h: Lineup?; let a: Lineup? }
    let state: String
    let detail: String
    let h: Side
    let a: Side
    let events: [Event]
    let stats: [[String]]
    let lineups: Lineups
    let venue: String?
    let ref: String?
}

// MARK: Laden

final class FeedService: ObservableObject {
    static let shared = FeedService()
    @Published private(set) var sport: SportFeed?
    @Published private(set) var news: NewsFeed?
    @Published private(set) var sportAt: Date?
    @Published private(set) var newsAt: Date?

    private func get<T: Decodable>(_ path: String, _ query: [URLQueryItem] = []) async throws -> T {
        let data = try await SupabaseClient.shared.raw("GET", "/functions/v1/feeds/" + path, query: query)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Sport: alle 30 s, solange etwas live ist oder gleich beginnt, sonst alle 10 min
    var sportInterval: TimeInterval {
        let now = Date()
        let hot = sport?.matches.contains { $0.isLive || ($0.state == "pre" && $0.start < now.addingTimeInterval(300) && $0.start > now.addingTimeInterval(-3 * 3600)) } ?? false
        return hot ? 30 : 600
    }

    func loadSport() async {
        if let t = sportAt, Date().timeIntervalSince(t) < sportInterval - 2 { return }
        do { sport = try await get("sport"); sportAt = Date() } catch { print("Sport:", error) }
    }

    func loadNews() async {
        if let t = newsAt, Date().timeIntervalSince(t) < 300 { return }
        do { news = try await get("news"); newsAt = Date() } catch { print("News:", error) }
    }

    func match(lg: String, id: String) async throws -> MatchDetail {
        try await get("match", [URLQueryItem(name: "lg", value: lg), URLQueryItem(name: "id", value: id)])
    }

    func article(_ key: String) async throws -> Article {
        try await get("article", [URLQueryItem(name: "u", value: key)])
    }
}

/// Wiederholt eine Ladefunktion, solange die Ansicht sichtbar ist
struct RefreshLoop: ViewModifier {
    let every: () -> TimeInterval
    let action: () async -> Void
    func body(content: Content) -> some View {
        content.task {
            while !Task.isCancelled {
                await action()
                try? await Task.sleep(nanoseconds: UInt64(max(10, every()) * 1_000_000_000))
            }
        }
    }
}

extension View {
    func refreshing(every: @escaping () -> TimeInterval, _ action: @escaping () async -> Void) -> some View {
        modifier(RefreshLoop(every: every, action: action))
    }
}
