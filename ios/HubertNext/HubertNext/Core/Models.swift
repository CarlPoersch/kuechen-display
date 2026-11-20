import Foundation

struct Profile: Codable, Equatable {
    var id: String
    var name: String?
    var interests: [String]
    var onboarded: Bool
}

struct Household: Codable, Equatable {
    var id: String
    var name: String
    var inviteCode: String

    enum CodingKeys: String, CodingKey { case id, name, inviteCode = "invite_code" }
}

/// Größe eines Buckets auf der Startseite
enum BucketSize: String, Codable, CaseIterable, Identifiable {
    case s, m, l
    var id: String { rawValue }
    var label: String { self == .s ? "Klein" : self == .m ? "Mittel" : "Groß" }
}

/// Ein Bucket, den jemand auf seiner Startseite hat (Zeile in user_buckets)
struct BucketInstance: Codable, Identifiable, Equatable {
    var id: String
    var bucket: String
    var position: Int
    var size: BucketSize
    var config: [String: JSON]

    init(kind: String, position: Int, size: BucketSize, config: [String: JSON]) {
        self.id = UUID().uuidString.lowercased()
        self.bucket = kind
        self.position = position
        self.size = size
        self.config = config
    }
}

/// Interessen fürs Onboarding (aus ihnen werden Buckets vorgeschlagen)
struct Interest: Identifiable {
    let id: String
    let name: String
    let symbol: String

    static let all: [Interest] = [
        Interest(id: "wetter", name: "Wetter & Natur", symbol: "cloud.sun"),
        Interest(id: "news", name: "News & Politik", symbol: "newspaper"),
        Interest(id: "sport", name: "Sport", symbol: "sportscourt"),
        Interest(id: "organisation", name: "Termine & Planung", symbol: "calendar"),
        Interest(id: "unterwegs", name: "Unterwegs & Reisen", symbol: "tram"),
        Interest(id: "haushalt", name: "Kochen & Haushalt", symbol: "fork.knife"),
        Interest(id: "gesundheit", name: "Gesundheit & Gewohnheiten", symbol: "heart"),
        Interest(id: "lernen", name: "Uni & Arbeit", symbol: "graduationcap"),
        Interest(id: "freizeit", name: "Freizeit & Kultur", symbol: "film"),
        Interest(id: "technik", name: "Technik", symbol: "cpu"),
    ]
}
