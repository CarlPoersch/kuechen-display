import Foundation
import Network
import Security

// ============================================================
// TLS-Verbindung mit eigenem Client-Zertifikat (Network.framework),
// Nachrichten mit Varint-Längenpräfix. Für die Android-TV-Fernbedienung.
// Das Zertifikat des Fernsehers ist selbst signiert – wir nehmen es an
// (nur im eigenen WLAN) und merken es uns für den Kopplungs-Code.
// ============================================================

enum RemoteError: LocalizedError {
    case message(String)
    case needsPairing
    case timeout

    var errorDescription: String? {
        switch self {
        case .message(let m): return m
        case .needsPairing: return "Noch nicht gekoppelt."
        case .timeout: return "Keine Antwort – ist das Gerät an und im selben WLAN?"
        }
    }
}

/// Einmal-Schalter für Fortsetzungen (Antwort kommt nur einmal an)
final class OnceFlag { var done = false }

final class TLSChannel {
    private var conn: NWConnection?
    private var framer = PBFramer()
    var onMessage: ((Data) -> Void)?
    var onClose: ((Error?) -> Void)?
    private(set) var serverCert: SecCertificate?

    func connect(host: String, port: UInt16, identity: SecIdentity, timeout: Double = 6) async throws {
        let tls = NWProtocolTLS.Options()
        let sp = tls.securityProtocolOptions
        if let sid = sec_identity_create(identity) { sec_protocol_options_set_local_identity(sp, sid) }
        sec_protocol_options_set_min_tls_protocol_version(sp, .TLSv12)
        sec_protocol_options_set_verify_block(sp, { [weak self] _, trust, complete in
            let t = sec_trust_copy_ref(trust).takeRetainedValue()
            let first = (SecTrustCopyCertificateChain(t) as? [SecCertificate])?.first
            DispatchQueue.main.async { self?.serverCert = first }
            complete(true)
        }, .main)

        guard let p = NWEndpoint.Port(rawValue: port) else { throw RemoteError.message("Ungültiger Port") }
        let c = NWConnection(host: NWEndpoint.Host(host), port: p, using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()))
        conn = c
        let once = OnceFlag()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        if !once.done { once.done = true; cont.resume(); self?.receive() }
                    case .failed(let e), .waiting(let e):
                        if !once.done { once.done = true; cont.resume(throwing: e); c.cancel() }
                        else { self?.onClose?(e) }
                    case .cancelled:
                        if !once.done { once.done = true; cont.resume(throwing: RemoteError.timeout) }
                        else { self?.onClose?(nil) }
                    default: break
                    }
                }
            }
            c.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if !once.done { once.done = true; cont.resume(throwing: RemoteError.timeout); c.cancel() }
            }
        }
    }

    private func receive() {
        conn?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, done, err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let d = data, !d.isEmpty {
                    for m in self.framer.append(d) { self.onMessage?(m) }
                }
                if done || err != nil { self.onClose?(err); return }
                self.receive()
            }
        }
    }

    func send(_ w: PBWriter) {
        conn?.send(content: w.framed, completion: .contentProcessed { _ in })
    }

    func close() {
        conn?.stateUpdateHandler = nil
        conn?.cancel()
        conn = nil
    }
}
