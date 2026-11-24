import Foundation
import Network

// ============================================================
// Lokales Tuya-Protokoll: eine kurze TCP-Verbindung zu Port 6668 pro Vorgang
// (verbinden → ggf. Sitzungsschlüssel aushandeln → abfragen/schalten → trennen).
// Viele Steckdosen erlauben nur eine Verbindung gleichzeitig – darum kurz halten.
//
// Rahmen 55AA (3.3, 3.4):
//   000055AA · seq · cmd · len · [Nutzdaten] · CRC32 (3.3) bzw. HMAC-SHA256 (3.4) · 0000AA55
//   len = Nutzdaten + Prüfsumme + Endmarke. Antworten des Geräts beginnen mit 4 Byte Rückgabecode.
// Rahmen 6699 (3.5):
//   00006699 · 0000 · seq · cmd · len · IV(12) · Geheimtext · Tag(16) · 00009966
//   AES-GCM, zusätzlich geprüft: die 14 Kopfbytes nach dem Präfix.
//
// Alles läuft auf dem Hauptthread (wie die Fernbedienung) – die Datenmengen sind winzig.
// ============================================================

enum TuyaVersion: String, CaseIterable {
    case v33 = "3.3"
    case v33d = "3.3d"      // 3.3-Geräte, die Abfragen nur als „neuen Befehl“ annehmen (tinytuya: device22)
    case v34 = "3.4"
    case v35 = "3.5"

    /// Reihenfolge beim Erkennen: 3.3 ist bei älteren Steckdosen am häufigsten
    static let detectOrder: [TuyaVersion] = [.v33, .v34, .v35]

    var header: Data {
        let v = self == .v33d ? "3.3" : rawValue
        return Data(v.utf8) + Data(count: 12)
    }
}

enum TuyaError: LocalizedError {
    case timeout, closed, wrongKey, badReply, needsDevice22

    var errorDescription: String? {
        switch self {
        case .timeout: return "Die Steckdose antwortet nicht."
        case .closed: return "Die Steckdose hat die Verbindung beendet."
        case .wrongKey: return "Der Schlüssel passt nicht mehr – Geräte neu laden."
        case .badReply: return "Unerwartete Antwort der Steckdose."
        case .needsDevice22: return "Ältere Steckdose (wird automatisch angepasst)."
        }
    }
}

private enum Cmd {
    static let negStart: UInt32 = 3, negResp: UInt32 = 4, negFinish: UInt32 = 5
    static let control: UInt32 = 7, status: UInt32 = 8, heartbeat: UInt32 = 9
    static let query: UInt32 = 10, controlNew: UInt32 = 13, queryNew: UInt32 = 16
}

private struct Frame {
    let cmd: UInt32
    let payload: Data       // ohne Rückgabecode; bei 6699 schon entschlüsselt
    let checksumOK: Bool
}

final class TuyaSession {
    let devId: String
    let version: TuyaVersion
    private let localKey: Data
    private var key: Data          // Sitzungsschlüssel (3.4/3.5) bzw. lokaler Schlüssel (3.3)
    private var conn: NWConnection?
    private var buffer = Data()
    private var seq: UInt32 = 1
    private var closed = false

    private init(devId: String, localKey: String, version: TuyaVersion) {
        self.devId = devId
        self.version = version
        self.localKey = Data(localKey.utf8)
        self.key = self.localKey
    }

    // MARK: Öffentlich

    /// Verbinden und (bei 3.4/3.5) den Sitzungsschlüssel aushandeln.
    /// Wirft `.wrongKey`, wenn die Steckdose mit diesem Schlüssel nichts anfangen kann.
    static func open(host: String, devId: String, localKey: String, version: TuyaVersion,
                     timeout: Double = 1.5) async throws -> TuyaSession {
        let s = TuyaSession(devId: devId, localKey: localKey, version: version)
        guard s.localKey.count == 16 else { throw TuyaError.wrongKey }
        do {
            try await s.connect(host: host, timeout: timeout)
            if version == .v34 || version == .v35 { try await s.negotiate() }
            return s
        } catch {
            s.close()
            throw error
        }
    }

    func close() {
        closed = true
        conn?.stateUpdateHandler = nil
        conn?.cancel()
        conn = nil
    }

    /// Alle Datenpunkte abfragen, z. B. ["1": true, "9": 0]
    func query(dps wanted: [Int] = [1]) async throws -> [String: Any] {
        switch version {
        case .v33:
            let body = json(["gwId": devId, "devId": devId, "uid": devId, "t": String(Int(Date().timeIntervalSince1970))])
            guard let enc = TuyaCrypto.ecb(body, key: key, encrypt: true) else { throw TuyaError.badReply }
            try send(pack55(Cmd.query, enc))
        case .v33d:
            var dps: [String: Any] = [:]
            for d in wanted { dps[String(d)] = NSNull() }
            let body = json(["devId": devId, "uid": devId, "t": String(Int(Date().timeIntervalSince1970)), "dps": dps])
            guard let enc = TuyaCrypto.ecb(body, key: key, encrypt: true) else { throw TuyaError.badReply }
            try send(pack55(Cmd.controlNew, version.header + enc))
        case .v34:
            guard let enc = TuyaCrypto.ecb(Data("{}".utf8), key: key, encrypt: true) else { throw TuyaError.badReply }
            try send(pack55(Cmd.queryNew, enc, hmacKey: key))
        case .v35:
            try send(pack66(Cmd.queryNew, Data("{}".utf8), key: key))
        }
        let deadline = Date().addingTimeInterval(2.5)
        while Date() < deadline {
            let f = try await readFrame(until: deadline)
            if let dps = try decodeDps(f) { return dps }
        }
        throw TuyaError.timeout
    }

    /// Datenpunkte setzen, z. B. ["1": true]. Liefert gemeldete Werte, falls die Steckdose sie schickt.
    @discardableResult
    func set(_ dps: [String: Any]) async throws -> [String: Any]? {
        let now = Int(Date().timeIntervalSince1970)
        switch version {
        case .v33, .v33d:
            let body = json(["devId": devId, "uid": devId, "t": String(now), "dps": dps])
            guard let enc = TuyaCrypto.ecb(body, key: key, encrypt: true) else { throw TuyaError.badReply }
            try send(pack55(Cmd.control, version.header + enc))
        case .v34:
            let body = version.header + json(["protocol": 5, "t": now, "data": ["dps": dps]])
            guard let enc = TuyaCrypto.ecb(body, key: key, encrypt: true) else { throw TuyaError.badReply }
            try send(pack55(Cmd.controlNew, enc, hmacKey: key))
        case .v35:
            let body = version.header + json(["protocol": 5, "t": now, "data": ["dps": dps]])
            try send(pack66(Cmd.controlNew, body, key: key))
        }
        // Bestätigung abwarten (kurz). Die meisten Steckdosen schicken erst eine leere Quittung,
        // dann eine Statusmeldung mit den neuen Werten.
        let deadline = Date().addingTimeInterval(1.2)
        while Date() < deadline {
            guard let f = try? await readFrame(until: deadline) else { break }
            if let d = try? decodeDps(f) { return d }
        }
        return nil
    }

    // MARK: Verbindung

    private func connect(host: String, timeout: Double) async throws {
        let c = NWConnection(host: NWEndpoint.Host(host), port: 6668, using: .tcp)
        conn = c
        let once = OnceFlag()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        if !once.done { once.done = true; cont.resume() }
                    case .failed(let e), .waiting(let e):
                        if !once.done { once.done = true; cont.resume(throwing: e); c.cancel() }
                        else { self?.closed = true }
                    case .cancelled:
                        if !once.done { once.done = true; cont.resume(throwing: TuyaError.timeout) }
                        self?.closed = true
                    default: break
                    }
                }
            }
            c.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if !once.done { once.done = true; cont.resume(throwing: TuyaError.timeout); c.cancel() }
            }
        }
    }

    private func send(_ data: Data) throws {
        guard let c = conn, !closed else { throw TuyaError.closed }
        c.send(content: data, completion: .contentProcessed { _ in })
    }

    /// Weitere Bytes lesen (bis zur Frist)
    private func receiveMore(until deadline: Date) async throws {
        guard let c = conn, !closed else { throw TuyaError.closed }
        let wait = max(0.05, deadline.timeIntervalSinceNow)
        let once = OnceFlag()
        let chunk: Data = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            c.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, done, err in
                DispatchQueue.main.async {
                    guard !once.done else { return }
                    once.done = true
                    if let d = data, !d.isEmpty { cont.resume(returning: d) }
                    else if done || err != nil { cont.resume(throwing: TuyaError.closed) }
                    else { cont.resume(returning: Data()) }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                if !once.done { once.done = true; cont.resume(throwing: TuyaError.timeout) }
            }
        }
        if chunk.isEmpty && closed { throw TuyaError.closed }
        buffer.append(chunk)
    }

    // MARK: Rahmen lesen

    private func readFrame(until deadline: Date) async throws -> Frame {
        while true {
            if let f = try takeFrame() { return f }
            if Date() >= deadline { throw TuyaError.timeout }
            try await receiveMore(until: deadline)
        }
    }

    private static let p55: [UInt8] = [0x00, 0x00, 0x55, 0xAA]
    private static let p66: [UInt8] = [0x00, 0x00, 0x66, 0x99]

    /// Einen vollständigen Rahmen aus dem Puffer nehmen (nil = noch nicht genug Daten)
    private func takeFrame() throws -> Frame? {
        // Bis zum nächsten Präfix vorspulen
        while buffer.count >= 4 {
            let head = [UInt8](buffer.prefix(4))
            if head == Self.p55 || head == Self.p66 { break }
            buffer = buffer.tuyaSlice(from: 1)
        }
        guard buffer.count >= 16 else { return nil }
        let is66 = [UInt8](buffer.prefix(4)) == Self.p66

        if !is66 {
            let len = Int(buffer.be32(at: 12))
            guard len >= 8, len < 0x10000 else { buffer = buffer.tuyaSlice(from: 4); throw TuyaError.badReply }
            let total = 16 + len
            guard buffer.count >= total else { return nil }
            let raw = buffer.tuyaSlice(0, total)
            buffer = buffer.tuyaSlice(from: total)
            let cmd = raw.be32(at: 8)
            let usesHmac = version == .v34
            let endLen = usesHmac ? 36 : 8
            guard len >= endLen else { throw TuyaError.badReply }
            var payload = raw.tuyaSlice(16, len - endLen)
            let signed = raw.tuyaSlice(0, total - endLen)
            let ok: Bool
            if usesHmac {
                ok = TuyaCrypto.hmac(signed, key: key) == raw.tuyaSlice(total - endLen, 32)
            } else {
                ok = TuyaCrypto.crc32(signed) == raw.be32(at: total - endLen)
            }
            payload = stripRetcode55(payload)
            return Frame(cmd: cmd, payload: payload, checksumOK: ok)
        } else {
            guard buffer.count >= 18 else { return nil }
            let len = Int(buffer.be32(at: 14))
            guard len >= 28, len < 0x10000 else { buffer = buffer.tuyaSlice(from: 4); throw TuyaError.badReply }
            let total = 18 + len + 4
            guard buffer.count >= total else { return nil }
            let raw = buffer.tuyaSlice(0, total)
            buffer = buffer.tuyaSlice(from: total)
            let cmd = raw.be32(at: 10)
            let aad = raw.tuyaSlice(4, 14)
            let iv = raw.tuyaSlice(18, 12)
            let cipher = raw.tuyaSlice(30, len - 12 - 16)
            let tag = raw.tuyaSlice(18 + len - 16, 16)
            guard var plain = TuyaCrypto.gcmOpen(cipher, key: key, iv: iv, tag: tag, aad: aad) else {
                return Frame(cmd: cmd, payload: Data(), checksumOK: false)
            }
            // 3.5: Antworten beginnen immer mit 4 Byte Rückgabecode
            if plain.count >= 4 && (cmd == Cmd.negResp ? plain.count >= 52 : plain.first == 0) {
                plain = plain.tuyaSlice(from: 4)
            }
            return Frame(cmd: cmd, payload: plain, checksumOK: true)
        }
    }

    /// 55AA: Rückgabecode (4 Byte) entfernen. Verschlüsselte Daten sind immer ein Vielfaches von 16,
    /// bei 3.3 evtl. mit 15 Byte Versionskopf davor – daran erkennt man, ob ein Code davorsteht.
    private func stripRetcode55(_ p: Data) -> Data {
        guard p.count >= 4 else { return Data() }
        let r = p.count % 16
        let hasCode: Bool
        switch version {
        case .v33, .v33d: hasCode = (r == 4 || r == 3)      // Code + Daten (16k) bzw. Code + Kopf(15) + Daten
        default: hasCode = (r == 4)
        }
        if p.count == 4 { return Data() }                    // nur Quittung
        return hasCode ? p.tuyaSlice(from: 4) : p
    }

    // MARK: Inhalte entschlüsseln

    /// Datenpunkte aus einem Rahmen holen (nil = Rahmen ohne Datenpunkte, z. B. Quittung)
    private func decodeDps(_ f: Frame) throws -> [String: Any]? {
        if f.cmd == Cmd.heartbeat || f.payload.isEmpty { return nil }
        var p = f.payload
        switch version {
        case .v33, .v33d:
            if p.starts(with: Data("3.3".utf8)) { p = p.tuyaSlice(from: 15) }
            guard let dec = TuyaCrypto.ecb(p, key: key, encrypt: false) else {
                // Klartext-Fehler wie „json obj data unvalid“
                if let t = String(data: f.payload, encoding: .utf8), t.contains("unvalid") { throw TuyaError.needsDevice22 }
                // Verschlüsselte Antwort, die sich nicht öffnen lässt → anderer Schlüssel
                if f.payload.count >= 16 && f.payload.count % 16 == 0 { throw TuyaError.wrongKey }
                return nil
            }
            if let t = String(data: dec, encoding: .utf8), t.contains("unvalid") { throw TuyaError.needsDevice22 }
            p = dec
        case .v34:
            guard f.checksumOK else { throw TuyaError.wrongKey }
            guard let dec = TuyaCrypto.ecbOpen(p, key: key) else { return nil }
            p = dec
            if p.starts(with: Data("3.4".utf8)) { p = p.tuyaSlice(from: 15) }
        case .v35:
            guard f.checksumOK else { throw TuyaError.wrongKey }
            if p.starts(with: Data("3.5".utf8)) { p = p.tuyaSlice(from: 15) }
        }
        guard let obj = (try? JSONSerialization.jsonObject(with: p)) as? [String: Any] else { return nil }
        if let dps = obj["dps"] as? [String: Any] { return dps }
        if let data = obj["data"] as? [String: Any], let dps = data["dps"] as? [String: Any] { return dps }
        return nil
    }

    // MARK: Sitzungsschlüssel (3.4 / 3.5)

    private func negotiate() async throws {
        let local = TuyaCrypto.random(16)
        key = localKey
        if version == .v34 {
            guard let enc = TuyaCrypto.ecb(local, key: localKey, encrypt: true) else { throw TuyaError.badReply }
            try send(pack55(Cmd.negStart, enc, hmacKey: localKey))
        } else {
            try send(pack66(Cmd.negStart, local, key: localKey))
        }

        let deadline = Date().addingTimeInterval(1.5)
        var reply: Frame?
        while Date() < deadline {
            let f = try await readFrame(until: deadline)
            if f.cmd == Cmd.negResp { reply = f; break }
        }
        guard let r = reply, r.checksumOK else { throw TuyaError.wrongKey }

        var body = r.payload
        if version == .v34 {
            guard let dec = TuyaCrypto.ecbOpen(body, key: localKey) else { throw TuyaError.wrongKey }
            body = dec
        }
        guard body.count >= 48 else { throw TuyaError.wrongKey }
        let remote = body.tuyaSlice(0, 16)
        guard body.tuyaSlice(16, 32) == TuyaCrypto.hmac(local, key: localKey) else { throw TuyaError.wrongKey }

        let finish = TuyaCrypto.hmac(remote, key: localKey)
        if version == .v34 {
            guard let enc = TuyaCrypto.ecb(finish, key: localKey, encrypt: true) else { throw TuyaError.badReply }
            try send(pack55(Cmd.negFinish, enc, hmacKey: localKey))
        } else {
            try send(pack66(Cmd.negFinish, finish, key: localKey))
        }

        let mixed = Data(zip(local, remote).map { $0 ^ $1 })
        if version == .v34 {
            guard let k = TuyaCrypto.ecb(mixed, key: localKey, encrypt: true, pad: false) else { throw TuyaError.badReply }
            key = k
        } else {
            guard let sealed = TuyaCrypto.gcmSeal(mixed, key: localKey, iv: local.tuyaSlice(0, 12), aad: Data()) else { throw TuyaError.badReply }
            key = sealed.0
        }
    }

    // MARK: Rahmen bauen

    private func nextSeq() -> UInt32 { defer { seq &+= 1 }; return seq }

    private func pack55(_ cmd: UInt32, _ payload: Data, hmacKey: Data? = nil) -> Data {
        var d = Data()
        d.append(contentsOf: Self.p55)
        d.appendBE32(nextSeq())
        d.appendBE32(cmd)
        d.appendBE32(UInt32(payload.count + (hmacKey == nil ? 8 : 36)))
        d.append(payload)
        if let k = hmacKey { d.append(TuyaCrypto.hmac(d, key: k)) }
        else { d.appendBE32(TuyaCrypto.crc32(d)) }
        d.append(contentsOf: [0x00, 0x00, 0xAA, 0x55])
        return d
    }

    private func pack66(_ cmd: UInt32, _ plain: Data, key k: Data) -> Data {
        var d = Data()
        d.append(contentsOf: Self.p66)
        d.appendBE16(0)
        d.appendBE32(nextSeq())
        d.appendBE32(cmd)
        d.appendBE32(UInt32(12 + plain.count + 16))
        let iv = TuyaCrypto.random(12)
        let (c, tag) = TuyaCrypto.gcmSeal(plain, key: k, iv: iv, aad: d.tuyaSlice(4, 14)) ?? (Data(), Data())
        d.append(iv); d.append(c); d.append(tag)
        d.append(contentsOf: [0x00, 0x00, 0x99, 0x66])
        return d
    }

    private func json(_ o: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: o)) ?? Data("{}".utf8)
    }
}

// MARK: Bequeme Einzelvorgänge

enum TuyaLocal {
    /// Abfragen; erkennt bei Bedarf die 3.3-Sonderform automatisch.
    /// Liefert die Datenpunkte und die tatsächlich passende Version.
    static func query(host: String, devId: String, key: String, version: TuyaVersion,
                      dps: [Int]) async throws -> ([String: Any], TuyaVersion) {
        let s = try await TuyaSession.open(host: host, devId: devId, localKey: key, version: version)
        defer { s.close() }
        do {
            return (try await s.query(dps: dps), version)
        } catch TuyaError.needsDevice22 where version == .v33 {
            s.close()
            let s2 = try await TuyaSession.open(host: host, devId: devId, localKey: key, version: .v33d)
            defer { s2.close() }
            return (try await s2.query(dps: dps), .v33d)
        }
    }

    static func set(host: String, devId: String, key: String, version: TuyaVersion,
                    dps: [String: Any]) async throws -> [String: Any]? {
        let s = try await TuyaSession.open(host: host, devId: devId, localKey: key, version: version)
        defer { s.close() }
        return try await s.set(dps)
    }

    /// Passt dieser Schlüssel zum Gerät unter `host`? Probiert die Versionen durch.
    static func identify(host: String, devId: String, key: String, dps: [Int],
                         versions: [TuyaVersion] = TuyaVersion.detectOrder) async -> (TuyaVersion, [String: Any])? {
        for v in versions {
            if let found = try? await query(host: host, devId: devId, key: key, version: v, dps: dps) {
                return (found.1, found.0)
            }
        }
        return nil
    }
}
