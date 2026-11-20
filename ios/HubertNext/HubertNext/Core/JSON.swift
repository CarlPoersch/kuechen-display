import Foundation

/// Beliebiger JSON-Wert. Damit speichert jeder Bucket seine eigenen Einstellungen,
/// ohne dass die Datenbank für jeden Bucket neue Spalten braucht.
enum JSON: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSON])
    case object([String: JSON])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSON].self) { self = .array(v) }
        else if let v = try? c.decode([String: JSON].self) { self = .object(v) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unbekannter JSON-Wert") }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    var string: String? { if case .string(let v) = self { return v }; return nil }
    var double: Double? { if case .number(let v) = self { return v }; return nil }
    var bool: Bool? { if case .bool(let v) = self { return v }; return nil }
    var array: [JSON]? { if case .array(let v) = self { return v }; return nil }
    var object: [String: JSON]? { if case .object(let v) = self { return v }; return nil }
}
