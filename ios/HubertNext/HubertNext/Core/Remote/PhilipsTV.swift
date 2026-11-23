import Foundation
import CryptoKit

// ============================================================
// Philips-Fernseher über die JointSPACE-Schnittstelle.
//   ohne Android: http://IP:1925/{6|5|1}/…  – ohne Anmeldung
//   mit Android:  https://IP:1926/6/…       – einmal koppeln (PIN auf dem TV), danach Digest-Anmeldung
// Vorlage: github.com/eslavnov/pylips (Ablauf der Kopplung, Tastennamen)
// ============================================================

struct PhilipsVariant: Equatable {
    var api: Int
    var secure: Bool        // https:1926 mit Kopplung

    var json: JSON { .object(["api": .number(Double(api)), "secure": .bool(secure)]) }
    init(api: Int, secure: Bool) { self.api = api; self.secure = secure }
    init?(_ j: JSON?) {
        guard let o = j?.object, let a = o["api"]?.double else { return nil }
        api = Int(a); secure = o["secure"]?.bool ?? false
    }
}

final class PhilipsTV {
    let host: String
    var variant: PhilipsVariant
    private var user: String?
    private var pass: String?
    private var session: URLSession

    /// Fester Schlüssel aus der Philips-App, mit dem die Kopplung signiert wird (bekannt aus pylips)
    private static let pairingSecret = Data(base64Encoded: "JCqdN5AcnAHgJYseUn7ER5k3qgtemfUvMRghQpTfTZq7Cvv8EPQPqfz6dDxPQPSu4gKFPWkJGw32zyASgJkHwCjU") ?? Data()

    init(host: String, variant: PhilipsVariant, credentials: (String, String)?) {
        self.host = host; self.variant = variant
        user = credentials?.0; pass = credentials?.1
        session = Self.makeSession(host: host, user: user, pass: pass)
    }

    private static func makeSession(host: String, user: String?, pass: String?) -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 3
        return URLSession(configuration: cfg, delegate: PhilipsAuth(host: host, user: user, pass: pass), delegateQueue: nil)
    }

    private var base: String { variant.secure ? "https://\(host):1926/\(variant.api)/" : "http://\(host):1925/\(variant.api)/" }

    var needsPairing: Bool { variant.secure && (user == nil || pass == nil) }

    // MARK: Erkennen

    /// Probiert die bekannten Varianten der Schnittstelle der Reihe nach aus
    static func detect(host: String) async -> PhilipsVariant? {
        let s = makeSession(host: host, user: nil, pass: nil)
        let tries: [(String, Int)] = [("http://\(host):1925/6/system", 6), ("http://\(host):1925/5/system", 5),
                                      ("http://\(host):1925/1/system", 1), ("https://\(host):1926/6/system", 6)]
        for (url, api) in tries {
            guard let u = URL(string: url), let res = try? await s.data(from: u),
                  let http = res.1 as? HTTPURLResponse else { continue }
            let data = res.0
            if http.statusCode == 401 && url.hasPrefix("https") { return PhilipsVariant(api: 6, secure: true) }
            guard http.statusCode == 200 else { continue }
            let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let major = ((o?["api_version"] as? [String: Any])?["Major"] as? Int) ?? api
            let pairing = (((o?["featuring"] as? [String: Any])?["systemfeatures"] as? [String: Any])?["pairing_type"] as? String)
            let secure = pairing == "digest_auth_pairing" || url.hasPrefix("https")
            return PhilipsVariant(api: secure ? 6 : major, secure: secure)
        }
        return nil
    }

    // MARK: Tasten

    func send(_ key: RemoteKey) async throws {
        guard let name = key.philips else { return }
        guard !needsPairing else { throw RemoteError.needsPairing }
        try await post("input/key", ["key": name])
    }

    @discardableResult
    private func post(_ path: String, _ body: [String: Any]) async throws -> Data {
        guard let u = URL(string: base + path) else { throw RemoteError.message("Ungültige Adresse") }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let res: (Data, URLResponse)
        do { res = try await session.data(for: r) }
        catch { throw RemoteError.timeout }
        let data = res.0, resp = res.1
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw RemoteError.needsPairing }
        guard (200..<300).contains(code) else { throw RemoteError.message("Der Fernseher hat abgelehnt (\(code)).") }
        return data
    }

    // MARK: Kopplung (nur Android-Modelle)

    private var pairingDevice: [String: Any] = [:]
    private var pairingTimestamp: Any = 0

    /// Fordert die Kopplung an – der Fernseher zeigt danach eine PIN
    func startPairing() async throws {
        let deviceId = String((0..<16).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
        pairingDevice = ["device_name": "Hubert", "device_os": "Android", "app_name": "Hubert", "type": "native",
                         "app_id": "app.id", "id": deviceId]
        let body: [String: Any] = ["scope": ["read", "write", "control"], "device": pairingDevice]
        let data = try await post("pair/request", body)
        let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (o?["error_id"] as? String) == "SUCCESS", let key = o?["auth_key"] as? String else {
            throw RemoteError.message("Der Fernseher hat die Kopplung nicht gestartet.")
        }
        pairingTimestamp = o?["timestamp"] ?? 0
        user = deviceId; pass = key
        session = Self.makeSession(host: host, user: user, pass: pass)
    }

    /// PIN vom Fernseher bestätigen. Rückgabe: Zugangsdaten zum Speichern
    func finishPairing(pin: String) async throws -> (String, String) {
        guard let u = user, let p = pass else { throw RemoteError.message("Bitte die Kopplung neu starten.") }
        let ts = "\(pairingTimestamp)"
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: Data((ts + pin).utf8), using: SymmetricKey(data: Self.pairingSecret))
        let hex = mac.map { String(format: "%02x", $0) }.joined()
        let signature = Data(hex.utf8).base64EncodedString()
        var device = pairingDevice; device["auth_key"] = p
        let body: [String: Any] = [
            "auth": ["auth_AppId": "1", "pin": pin, "auth_timestamp": pairingTimestamp, "auth_signature": signature],
            "device": device,
        ]
        try await post("pair/grant", body)
        return (u, p)
    }
}

/// Nimmt das selbst signierte Zertifikat des Fernsehers an (nur diese Adresse) und meldet sich per Digest an
final class PhilipsAuth: NSObject, URLSessionTaskDelegate {
    let host: String
    let user: String?
    let pass: String?
    init(host: String, user: String?, pass: String?) { self.host = host; self.user = user; self.pass = pass }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust, space.host == host, let trust = space.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else if space.authenticationMethod == NSURLAuthenticationMethodHTTPDigest, let u = user, let p = pass,
                  challenge.previousFailureCount == 0 {
            completionHandler(.useCredential, URLCredential(user: u, password: p, persistence: .forSession))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
