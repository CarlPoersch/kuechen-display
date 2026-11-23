import Foundation

// ============================================================
// Minimaler Protobuf-Kodierer/-Leser – nur was die Android-TV-Fernbedienung braucht
// (Varints und Felder mit Länge). Keine Fremdbibliothek.
// ============================================================

struct PBWriter {
    private(set) var data = Data()

    static func varint(_ v: UInt64) -> Data {
        var v = v, out = Data()
        repeat {
            var b = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { b |= 0x80 }
            out.append(b)
        } while v != 0
        return out
    }

    mutating func int(_ field: Int, _ value: Int) {
        data.append(Self.varint(UInt64(field << 3 | 0)))
        data.append(Self.varint(UInt64(bitPattern: Int64(value))))
    }

    mutating func bytes(_ field: Int, _ value: Data) {
        data.append(Self.varint(UInt64(field << 3 | 2)))
        data.append(Self.varint(UInt64(value.count)))
        data.append(value)
    }

    mutating func string(_ field: Int, _ value: String) { bytes(field, Data(value.utf8)) }

    mutating func message(_ field: Int, _ build: (inout PBWriter) -> Void) {
        var w = PBWriter(); build(&w); bytes(field, w.data)
    }

    /// Nachricht mit Längenpräfix (Rahmen auf der Leitung)
    var framed: Data { Self.varint(UInt64(data.count)) + data }
}

/// Gelesene Nachricht: Feldnummer → Werte (Varint als UInt64, Länge-Felder als Data)
struct PBMessage {
    var ints: [Int: [UInt64]] = [:]
    var blobs: [Int: [Data]] = [:]

    func int(_ f: Int) -> Int? { ints[f]?.first.map { Int(truncatingIfNeeded: $0) } }
    func blob(_ f: Int) -> Data? { blobs[f]?.first }
    func message(_ f: Int) -> PBMessage? { blob(f).flatMap { PBMessage($0) } }
    func string(_ f: Int) -> String? { blob(f).flatMap { String(data: $0, encoding: .utf8) } }
    func has(_ f: Int) -> Bool { ints[f] != nil || blobs[f] != nil }

    init?(_ data: Data) {
        let b = [UInt8](data)
        var i = 0
        func readVarint() -> UInt64? {
            var result: UInt64 = 0, shift: UInt64 = 0
            while i < b.count {
                let byte = b[i]; i += 1
                result |= UInt64(byte & 0x7F) << shift
                if byte & 0x80 == 0 { return result }
                shift += 7
                if shift > 63 { return nil }
            }
            return nil
        }
        while i < b.count {
            guard let key = readVarint() else { return nil }
            let field = Int(key >> 3), type = key & 7
            switch type {
            case 0:
                guard let v = readVarint() else { return nil }
                ints[field, default: []].append(v)
            case 2:
                guard let len = readVarint(), i + Int(len) <= b.count else { return nil }
                blobs[field, default: []].append(Data(b[i ..< i + Int(len)]))
                i += Int(len)
            case 1: i += 8          // 64 Bit – kommt hier nicht vor, überspringen
            case 5: i += 4          // 32 Bit
            default: return nil
            }
        }
    }

    init() {}
}

/// Puffer für eingehende Daten: liefert vollständige Nachrichten (Varint-Längenpräfix)
struct PBFramer {
    private var buffer = Data()

    mutating func append(_ d: Data) -> [Data] {
        buffer.append(d)
        var out: [Data] = []
        while true {
            let b = [UInt8](buffer)
            var i = 0, len: UInt64 = 0, shift: UInt64 = 0, done = false
            while i < b.count && i < 10 {
                let byte = b[i]; i += 1
                len |= UInt64(byte & 0x7F) << shift
                if byte & 0x80 == 0 { done = true; break }
                shift += 7
            }
            guard done, b.count >= i + Int(len) else { break }
            out.append(Data(b[i ..< i + Int(len)]))
            buffer = Data(b[(i + Int(len))...])
        }
        return out
    }
}
