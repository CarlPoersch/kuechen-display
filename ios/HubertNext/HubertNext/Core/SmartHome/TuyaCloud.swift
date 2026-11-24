import Foundation

// ============================================================
// Tuya-Cloud – nur für die Einrichtung und „Geräte neu laden“:
// holt alle Geräte der verknüpften Smart-Life-App mit Name, Kategorie
// und lokalem Schlüssel, dazu die Schalter-Datenpunkte jeder Steckdose.
// Geschaltet wird danach nur lokal (TuyaLocal).
//
// Signatur (Tuya OpenAPI, „neues“ Verfahren, wie tinytuya):
//   sign = HMAC-SHA256(secret, clientId + [accessToken] + t + stringToSign), Hex in Großbuchstaben
//   stringToSign = Methode \n SHA256(Body) \n (Header-Zeilen, hier leer) \n Pfad[?sortierte Query]
// ============================================================

enum TuyaRegion: String, CaseIterable, Identifiable {
    case centralEurope = "openapi.tuyaeu.com"
    case westernEurope = "openapi-weaz.tuyaeu.com"
    case westernAmerica = "openapi.tuyaus.com"
    case easternAmerica = "openapi-ueaz.tuyaus.com"
    case india = "openapi.tuyain.com"
    case china = "openapi.tuyacn.com"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .centralEurope: return "Mitteleuropa"
        case .westernEurope: return "Westeuropa"
        case .westernAmerica: return "Westamerika"
        case .easternAmerica: return "Ostamerika"
        case .india: return "Indien"
        case .china: return "China"
        }
    }
}

struct TuyaCloudDevice {
    let id: String
    let name: String
    let localKey: String
    let category: String
    let productId: String
    var switches: [(dp: Int, code: String)]
}

enum TuyaCloudError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
}

final class TuyaCloud {
    let accessId: String
    private let secret: String
    private let host: String
    private var token: String?

    init(accessId: String, secret: String, region: TuyaRegion) {
        self.accessId = accessId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        self.host = region.rawValue
    }

    /// Steckdosen (Kategorien cz = Steckdose, pc = Steckdosenleiste) mit ihren Schaltern
    func plugs() async throws -> [TuyaCloudDevice] {
        try await login()
        var all = try await devices()
        all = all.filter { ["cz", "pc"].contains($0.category) && !$0.localKey.isEmpty }
        for i in all.indices {
            all[i].switches = (try? await switches(all[i].id)) ?? []
            if all[i].switches.isEmpty { all[i].switches = [(1, "switch_1")] }   // übliche Belegung
        }
        return all
    }

    // MARK: Anfragen

    private func login() async throws {
        token = nil
        let r = try await call("GET", "/v1.0/token", query: [("grant_type", "1")])
        guard let res = r["result"] as? [String: Any], let t = res["access_token"] as? String else {
            throw TuyaCloudError.message("Anmeldung bei Tuya fehlgeschlagen.")
        }
        token = t
    }

    /// Alle Geräte: erst die verknüpften Nutzer, dann je Nutzer die Geräte mit lokalem Schlüssel
    private func devices() async throws -> [TuyaCloudDevice] {
        var users = Set<String>()
        var found: [String: TuyaCloudDevice] = [:]
        var lastRow: String?
        repeat {
            var q = [("size", "50")]
            if let l = lastRow { q.append(("last_row_key", l)) }
            let r = try await call("GET", "/v1.0/iot-01/associated-users/devices", query: q)
            let res = r["result"] as? [String: Any] ?? [:]
            for d in (res["devices"] as? [[String: Any]]) ?? (res["list"] as? [[String: Any]]) ?? [] {
                if let u = d["uid"] as? String { users.insert(u) }
                if let dev = Self.device(d) { found[dev.id] = dev }
            }
            lastRow = (res["has_more"] as? Bool) == true ? res["last_row_key"] as? String : nil
        } while lastRow != nil

        for uid in users {
            var lastRow: String?
            repeat {
                var q = [("page_size", "75"), ("source_type", "tuyaUser"), ("source_id", uid)]
                if let l = lastRow { q.append(("last_row_key", l)) }
                guard let r = try? await call("GET", "/v1.3/iot-03/devices", query: q) else { break }
                let res = r["result"] as? [String: Any] ?? [:]
                for d in (res["list"] as? [[String: Any]]) ?? (res["devices"] as? [[String: Any]]) ?? [] {
                    guard let dev = Self.device(d) else { continue }
                    if let old = found[dev.id], dev.localKey.isEmpty { found[dev.id] = old } else { found[dev.id] = dev }
                }
                lastRow = (res["has_more"] as? Bool) == true ? res["last_row_key"] as? String : nil
            } while lastRow != nil
        }
        return found.values.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private static func device(_ d: [String: Any]) -> TuyaCloudDevice? {
        guard let id = d["id"] as? String else { return nil }
        return TuyaCloudDevice(id: id, name: (d["name"] as? String) ?? "Steckdose",
                               localKey: (d["local_key"] as? String) ?? "",
                               category: (d["category"] as? String) ?? "",
                               productId: (d["product_id"] as? String) ?? "", switches: [])
    }

    /// Schalter-Datenpunkte: Codes „switch“, „switch_1“, „switch_2“ … (USB-Schalter zählen nicht)
    private func switches(_ id: String) async throws -> [(dp: Int, code: String)] {
        let r = try await call("GET", "/v1.1/devices/\(id)/specifications", query: [])
        let res = r["result"] as? [String: Any] ?? [:]
        var out: [Int: String] = [:]
        for key in ["functions", "status"] {
            for f in (res[key] as? [[String: Any]]) ?? [] {
                guard let code = f["code"] as? String, (f["type"] as? String)?.lowercased() == "boolean",
                      code == "switch" || code.range(of: #"^switch_\d+$"#, options: .regularExpression) != nil else { continue }
                let dp = (f["dp_id"] as? Int) ?? Int(code.split(separator: "_").last ?? "") ?? 1
                out[dp] = code
            }
        }
        return out.keys.sorted().map { ($0, out[$0]!) }
    }

    private func call(_ method: String, _ path: String, query: [(String, String)]) async throws -> [String: Any] {
        let sorted = query.sorted { $0.0 < $1.0 }
        let qs = sorted.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        let signPath = qs.isEmpty ? path : path + "?" + qs
        let t = String(Int64(Date().timeIntervalSince1970 * 1000))
        let toSign = method + "\n" + TuyaCrypto.sha256Hex(Data()) + "\n" + "\n" + signPath
        let sign = TuyaCrypto.hmacHexUpper(accessId + (token ?? "") + t + toSign, key: secret)

        var comps = URLComponents()
        comps.scheme = "https"; comps.host = host; comps.path = path
        if !sorted.isEmpty { comps.queryItems = sorted.map { URLQueryItem(name: $0.0, value: $0.1) } }
        guard let url = comps.url else { throw TuyaCloudError.message("Ungültige Adresse.") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue(accessId, forHTTPHeaderField: "client_id")
        req.setValue(sign, forHTTPHeaderField: "sign")
        req.setValue(t, forHTTPHeaderField: "t")
        req.setValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        if let tok = token { req.setValue(tok, forHTTPHeaderField: "access_token") }

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw TuyaCloudError.message("Tuya hat unerwartet geantwortet.")
        }
        if (obj["success"] as? Bool) != true {
            let code = (obj["code"] as? Int) ?? 0
            let msg = (obj["msg"] as? String) ?? "unbekannt"
            throw TuyaCloudError.message(Self.explain(code, msg))
        }
        return obj
    }

    /// Häufige Tuya-Fehler verständlich machen
    private static func explain(_ code: Int, _ msg: String) -> String {
        switch code {
        case 1004: return "Access Secret stimmt nicht (Tuya: Signatur ungültig)."
        case 1010: return "Anmeldung bei Tuya abgelaufen – bitte noch einmal versuchen."
        case 1106: return "Keine Berechtigung. Ist die Smart-Life-App im Projekt unter „Devices → Link App Account“ verknüpft?"
        default:
            if msg.lowercased().contains("data center") || msg.lowercased().contains("region") {
                return "Falsches Rechenzentrum. Wähle die Region deines Smart-Life-Kontos."
            }
            if msg.lowercased().contains("permission") || msg.lowercased().contains("expire") {
                return "Tuya verweigert den Zugriff (\(msg)). Im Tuya-Portal prüfen: Ist „IoT Core“ abonniert und noch nicht abgelaufen?"
            }
            return "Tuya meldet: \(msg) (\(code))"
        }
    }
}
