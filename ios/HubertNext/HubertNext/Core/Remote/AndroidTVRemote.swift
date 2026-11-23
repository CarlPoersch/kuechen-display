import Foundation
import CryptoKit
import Security

// ============================================================
// Android TV / Google TV (z. B. Xiaomi Mi TV Stick): Android TV Remote Protocol v2,
// dasselbe wie die Google-TV-App. Kein ADB, kein Entwicklermodus.
//   Kopplung  Port 6467 (polo.proto): Anfrage → Optionen → Konfiguration → TV zeigt 6-stelligen Code → Geheimnis
//   Steuerung Port 6466 (remotemessage.proto): Konfiguration, Ping/Pong, Tasten, Text
// Vorlage: github.com/tronikos/androidtvremote2 (Feldnummern aus den .proto-Dateien dort)
// ============================================================

// MARK: Kopplung

final class ATVPairing {
    private let ch = TLSChannel()
    private var identity: SecIdentity?
    private var started: CheckedContinuation<Void, Error>?
    private var finished: CheckedContinuation<Void, Error>?

    /// Grundgerüst jeder Kopplungs-Nachricht: protocol_version = 2, status = OK (200)
    private func outer(_ build: (inout PBWriter) -> Void) -> PBWriter {
        var w = PBWriter(); w.int(1, 2); w.int(2, 200); build(&w); return w
    }

    /// Verbindet und startet die Kopplung. Danach zeigt der Fernseher einen Code.
    func start(host: String) async throws {
        let id = try ClientIdentity.get()
        identity = id
        try await ch.connect(host: host, port: 6467, identity: id)
        ch.onMessage = { [weak self] in self?.handle($0) }
        ch.onClose = { [weak self] _ in self?.fail(RemoteError.message("Verbindung zum Gerät getrennt.")) }
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            started = c
            ch.send(outer { w in
                w.message(10) { r in r.string(1, "atvremote"); r.string(2, "Hubert") }   // pairing_request
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if let c = self?.started { self?.started = nil; c.resume(throwing: RemoteError.timeout) }
            }
        }
    }

    /// Code vom Fernseher eingeben (6 Zeichen, 0–9 und A–F)
    func finish(code raw: String) async throws {
        let code = raw.uppercased().filter { !$0.isWhitespace }
        guard code.count == 6, let codeBytes = Self.hex(code) else {
            throw RemoteError.message("Der Code hat 6 Zeichen (Ziffern und A–F).")
        }
        guard let id = identity, let client = ClientIdentity.publicNumbers(id),
              let cert = ch.serverCert, let server = RSAKey.numbers(of: cert) else {
            throw RemoteError.message("Kopplung unterbrochen – bitte neu starten.")
        }
        var h = SHA256()
        h.update(data: client.0); h.update(data: client.1)
        h.update(data: server.0); h.update(data: server.1)
        h.update(data: Data(codeBytes.dropFirst()))
        let secret = Data(h.finalize())
        // Das erste Byte des Codes ist eine Prüfsumme: so erkennen wir Tippfehler sofort
        guard secret.first == codeBytes.first else { throw RemoteError.message("Der Code stimmt nicht – bitte genau abtippen.") }
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            finished = c
            ch.send(outer { w in w.message(40) { s in s.bytes(1, secret) } })          // secret
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if let c = self?.finished { self?.finished = nil; c.resume(throwing: RemoteError.timeout) }
            }
        }
        ch.close()
    }

    func cancel() { ch.close(); fail(RemoteError.message("Abgebrochen.")) }

    private func handle(_ data: Data) {
        guard let m = PBMessage(data) else { return }
        let status = m.int(2) ?? 0
        guard status == 200 else {
            fail(RemoteError.message(status == 402 ? "Der Code stimmt nicht." : "Das Gerät hat die Kopplung abgelehnt (\(status))."))
            return
        }
        if m.has(11) {                                    // pairing_request_ack → Optionen
            ch.send(outer { w in
                w.message(20) { o in
                    o.message(1) { e in e.int(1, 3); e.int(2, 6) }   // Eingabe: hexadezimal, 6 Zeichen
                    o.int(3, 1)                                       // Rolle: Eingabe
                }
            })
        } else if m.has(20) {                             // options → Konfiguration
            ch.send(outer { w in
                w.message(30) { c in
                    c.message(1) { e in e.int(1, 3); e.int(2, 6) }
                    c.int(2, 1)
                }
            })
        } else if m.has(31) {                             // configuration_ack → Code steht auf dem TV
            started?.resume(); started = nil
        } else if m.has(41) {                             // secret_ack → gekoppelt
            finished?.resume(); finished = nil
        }
    }

    private func fail(_ e: Error) {
        started?.resume(throwing: e); started = nil
        finished?.resume(throwing: e); finished = nil
    }

    private static func hex(_ s: String) -> [UInt8]? {
        var out: [UInt8] = []; var it = s.makeIterator()
        while let a = it.next(), let b = it.next() {
            guard let v = UInt8(String([a, b]), radix: 16) else { return nil }
            out.append(v)
        }
        return out.count == 3 ? out : nil
    }
}

// MARK: Steuerung

final class ATVSession {
    private let ch = TLSChannel()
    private var active = 0
    private var imeCounter = 0
    private var fieldCounter = 0

    var onPower: ((Bool) -> Void)?
    var onVolume: ((Int, Int, Bool) -> Void)?      // Stufe, Maximum, stumm
    var onClose: ((Error?) -> Void)?

    // Gewünschte Funktionen: Ping, Tasten, Texteingabe, Ein/Aus, Lautstärke, App-Links
    private static let wanted = 1 | 2 | 4 | 32 | 64 | 512

    func connect(host: String) async throws {
        let id = try ClientIdentity.get()
        ch.onMessage = { [weak self] in self?.handle($0) }
        ch.onClose = { [weak self] e in self?.onClose?(e) }
        try await ch.connect(host: host, port: 6466, identity: id)
    }

    func close() { ch.close() }

    func press(_ key: RemoteKey) {
        guard let code = key.android else { return }
        var w = PBWriter()
        w.message(10) { k in k.int(1, code); k.int(2, 3) }       // remote_key_inject, SHORT
        ch.send(w)
    }

    /// Text in das gerade aktive Eingabefeld auf dem Fernseher schreiben
    func send(text: String) {
        guard !text.isEmpty else { return }
        let n = text.count
        var w = PBWriter()
        w.message(21) { b in                                       // remote_ime_batch_edit
            b.int(1, imeCounter); b.int(2, fieldCounter)
            b.message(3) { e in                                    // edit_info
                e.int(1, 1)
                e.message(2) { o in o.int(1, n); o.int(2, n); o.string(3, text) }
            }
        }
        ch.send(w)
    }

    private func handle(_ data: Data) {
        guard let m = PBMessage(data) else { return }
        var reply = PBWriter()
        if let cfg = m.message(1) {                                // remote_configure
            let supported = cfg.int(1) ?? 0
            active = supported == 0 ? Self.wanted : Self.wanted & supported
            reply.message(1) { c in
                c.int(1, active)
                c.message(2) { d in d.int(3, 1); d.string(4, "1"); d.string(5, "atvremote"); d.string(6, "1.0.0") }
            }
        } else if m.has(2) {                                       // remote_set_active
            reply.message(2) { a in a.int(1, active) }
        } else if let p = m.message(8) {                           // Ping → Pong
            reply.message(9) { r in r.int(1, p.int(1) ?? 0) }
        } else if let s = m.message(40) {                          // remote_start (an/aus)
            onPower?((s.int(1) ?? 0) == 1)
        } else if let v = m.message(50) {                          // Lautstärke
            onVolume?(v.int(7) ?? 0, v.int(6) ?? 0, (v.int(8) ?? 0) == 1)
        } else if let ime = m.message(20) {                        // aktives Eingabefeld
            if let c = ime.message(1)?.int(1), c != 0 { imeCounter = c }
            if let f = ime.message(2)?.int(1), f != 0 { fieldCounter = f }
        } else if let show = m.message(22) {
            if let f = show.message(2)?.int(1) { fieldCounter = f }
        } else if let be = m.message(21) {
            if imeCounter == 0 { imeCounter = be.int(1) ?? 0 }
            if fieldCounter == 0 { fieldCounter = be.int(2) ?? 0 }
        }
        if !reply.data.isEmpty { ch.send(reply) }
    }
}
