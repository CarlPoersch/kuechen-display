import Foundation

/// Fehler, die wir dem Nutzer verständlich anzeigen können
struct APIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
    var isAuth: Bool { status == 401 || status == 403 }
}

/// Angemeldete Sitzung (Zugangs-Token läuft nach ~1 Std ab, wird automatisch erneuert)
struct Session: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: String
}

/// Schlanker Zugriff auf Supabase (Anmeldung, Datenbank, Funktionen) nur mit Apple-Bordmitteln.
/// Warum kein Zusatzpaket: weniger Abhängigkeiten, läuft sicher auf iOS 15.
final class SupabaseClient {
    static let shared = SupabaseClient()

    private(set) var session: Session? {
        didSet { Keychain.save(session.flatMap { try? JSONEncoder().encode($0) }) }
    }

    private init() {
        if let data = Keychain.load() { session = try? JSONDecoder().decode(Session.self, from: data) }
    }

    var userId: String? { session?.userId }

    // MARK: Anmeldung

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Double
        let user: User
        struct User: Decodable { let id: String }
    }

    /// Mit Apple anmelden: Apple liefert ein Token, Supabase macht daraus eine Sitzung.
    func signInWithApple(idToken: String, nonce: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["provider": "apple", "id_token": idToken, "nonce": nonce])
        let data = try await raw("POST", "/auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "id_token")],
                                 body: body, auth: false)
        try store(data)
    }

    private func refresh() async throws {
        guard let s = session else { throw APIError(status: 401, message: "Nicht angemeldet") }
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": s.refreshToken])
        do {
            let data = try await raw("POST", "/auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                     body: body, auth: false)
            try store(data)
        } catch let e as APIError where e.status == 400 || e.isAuth {
            session = nil // Anmeldung ungültig → neu anmelden
            throw APIError(status: 401, message: "Bitte neu anmelden")
        }
    }

    private func store(_ data: Data) throws {
        let t = try JSONDecoder().decode(TokenResponse.self, from: data)
        session = Session(accessToken: t.access_token, refreshToken: t.refresh_token,
                          expiresAt: Date().addingTimeInterval(t.expires_in), userId: t.user.id)
    }

    func signOut() { session = nil }

    /// Gültiger Zugangsschlüssel (frischt bei Bedarf auf) – z. B. für die Live-Verbindung
    func currentToken() async -> String? {
        if let s = session, s.expiresAt < Date().addingTimeInterval(60) { try? await refresh() }
        return session?.accessToken
    }

    // MARK: Anfragen

    /// Grundfunktion für alle Anfragen. Erneuert die Anmeldung bei Bedarf einmal automatisch.
    func raw(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
             headers: [String: String] = [:], auth: Bool = true, retry: Bool = true) async throws -> Data {
        if auth, let s = session, s.expiresAt < Date().addingTimeInterval(60) { try await refresh() }
        var comps = URLComponents(url: Config.supabaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.httpBody = body
        req.timeoutInterval = 20
        req.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let s = session { req.setValue("Bearer " + s.accessToken, forHTTPHeaderField: "Authorization") }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && auth && retry && session != nil {
            try await refresh()
            return try await raw(method, path, query: query, body: body, headers: headers, auth: auth, retry: false)
        }
        guard (200..<300).contains(status) else {
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = (obj?["message"] ?? obj?["msg"] ?? obj?["error_description"] ?? obj?["error"]) as? String
            throw APIError(status: status, message: msg ?? "Fehler \(status)")
        }
        return data
    }

    /// Tabelle lesen, z. B. select("user_buckets", ["order": "position"])
    func select<T: Decodable>(_ table: String, _ params: [String: String] = [:]) async throws -> T {
        var q = [URLQueryItem(name: "select", value: "*")]
        q += params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try JSONDecoder().decode(T.self, from: try await raw("GET", "/rest/v1/" + table, query: q))
    }

    /// Datenbank-Funktion aufrufen (z. B. create_household)
    func rpc<T: Decodable>(_ name: String, _ params: [String: Any] = [:]) async throws -> T {
        let body = try JSONSerialization.data(withJSONObject: params)
        return try JSONDecoder().decode(T.self, from: try await raw("POST", "/rest/v1/rpc/" + name, body: body))
    }

    /// Zeilen ändern, z. B. update("profiles", ["id": "eq.123"], body)
    func update<B: Encodable>(_ table: String, _ filter: [String: String], _ body: B) async throws {
        let q = filter.map { URLQueryItem(name: $0.key, value: $0.value) }
        _ = try await raw("PATCH", "/rest/v1/" + table, query: q, body: try JSONEncoder().encode(body),
                          headers: ["Prefer": "return=minimal"])
    }

    /// Zeilen anlegen oder überschreiben (gleiche id → wird aktualisiert)
    func upsert<B: Encodable>(_ table: String, _ rows: B) async throws {
        _ = try await raw("POST", "/rest/v1/" + table, body: try JSONEncoder().encode(rows),
                          headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    func delete(_ table: String, _ filter: [String: String]) async throws {
        let q = filter.map { URLQueryItem(name: $0.key, value: $0.value) }
        _ = try await raw("DELETE", "/rest/v1/" + table, query: q, headers: ["Prefer": "return=minimal"])
    }
}
