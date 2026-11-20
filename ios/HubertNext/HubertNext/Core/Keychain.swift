import Foundation
import Security

/// Speichert die Anmeldung sicher im Schlüsselbund des Geräts.
/// Warum nicht UserDefaults: Dort könnte man die Zugangsdaten auslesen.
enum Keychain {
    private static let service = "com.carlpoersch.HubertNext.session"

    static func save(_ data: Data?) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
        guard let data = data else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
}
