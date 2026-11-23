import Foundation
import Combine
import Network
import Security

// ============================================================
// Fernbedienung: Geräte, Kopplungsdaten und die aktive Verbindung.
// Geräteliste (Name, Art, IP) steht in der Bucket-Konfiguration (im Haushalt geteilt).
// Kopplungen bleiben im Schlüsselbund bzw. auf diesem Gerät.
// ============================================================

struct RemoteDevice: Identifiable, Equatable {
    enum Kind: String { case philips, androidtv }
    var id = UUID().uuidString.lowercased()
    var name: String
    var kind: Kind
    var host: String
    var philips: PhilipsVariant? = nil

    var symbol: String { kind == .philips ? "tv" : "tv.and.mediabox" }
    var kindLabel: String { kind == .philips ? "Philips-Fernseher" : "Android TV / Google TV" }

    static func list(_ c: [String: JSON]) -> [RemoteDevice] {
        (c["devices"]?.array ?? []).compactMap { j in
            guard let o = j.object, let name = o["name"]?.string, let host = o["host"]?.string,
                  let kind = o["kind"]?.string.flatMap(Kind.init) else { return nil }
            return RemoteDevice(id: o["id"]?.string ?? host, name: name, kind: kind, host: host, philips: PhilipsVariant(o["philips"]))
        }
    }

    static func store(_ list: [RemoteDevice], in c: inout [String: JSON]) {
        c["devices"] = .array(list.map { d in
            var o: [String: JSON] = ["id": .string(d.id), "name": .string(d.name), "kind": .string(d.kind.rawValue), "host": .string(d.host)]
            if let v = d.philips { o["philips"] = v.json }
            return .object(o)
        })
    }
}

/// Zugangsdaten im Schlüsselbund (nur dieses Gerät)
enum RemoteSecrets {
    private static let service = "com.carlpoersch.hubert.remote"

    static func set(_ value: String?, for account: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        guard let v = value else { return }
        var add = q
        add[kSecValueData as String] = Data(v.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ account: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func philips(_ id: String) -> (String, String)? {
        guard let s = get("philips." + id) else { return nil }
        let p = s.split(separator: "\n", maxSplits: 1).map(String.init)
        return p.count == 2 ? (p[0], p[1]) : nil
    }
    static func setPhilips(_ id: String, _ c: (String, String)?) { set(c.map { $0.0 + "\n" + $0.1 }, for: "philips." + id) }

    /// Android TV: Wurde dieses Gerät von hier aus schon gekoppelt?
    static func atvPaired(_ id: String) -> Bool { UserDefaults.standard.bool(forKey: "remote.atvPaired." + id) }
    static func setAtvPaired(_ id: String, _ v: Bool) { UserDefaults.standard.set(v, forKey: "remote.atvPaired." + id) }
}

final class RemoteController: ObservableObject {
    static let shared = RemoteController()

    enum Phase: Equatable { case idle, connecting, ready, needsPairing, failed(String) }

    struct Volume: Equatable { let level: Int; let max: Int; let muted: Bool }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isOn: Bool?
    @Published private(set) var volume: Volume?
    @Published private(set) var device: RemoteDevice?

    /// Wird aufgerufen, wenn Hubert die Philips-Variante erkannt hat (zum Speichern in der Konfiguration)
    var onVariant: ((RemoteDevice) -> Void)?

    private var philips: PhilipsTV?
    private var atv: ATVSession?
    private var opening = false

    func open(_ d: RemoteDevice) {
        if device == d && (phase == .ready || phase == .connecting) { return }
        close()
        device = d
        Task { await connect() }
    }

    func retry() { guard device != nil else { return }; close(keepDevice: true); Task { await connect() } }

    func close(keepDevice: Bool = false) {
        atv?.close(); atv = nil; philips = nil
        isOn = nil; volume = nil
        phase = .idle
        if !keepDevice { device = nil }
    }

    private func connect() async {
        guard var d = device, !opening else { return }
        opening = true; defer { opening = false }
        phase = .connecting
        switch d.kind {
        case .philips:
            if d.philips == nil {
                guard let v = await PhilipsTV.detect(host: d.host) else {
                    phase = .failed("Der Fernseher antwortet nicht. Ist er an und im selben WLAN? Bei älteren Modellen die Schnittstelle einmal freischalten: auf der TV-Fernbedienung 5646877223 eingeben, während das Fernsehbild läuft.")
                    return
                }
                d.philips = v; device = d
                onVariant?(d)
            }
            let tv = PhilipsTV(host: d.host, variant: d.philips!, credentials: RemoteSecrets.philips(d.id))
            philips = tv
            phase = tv.needsPairing ? .needsPairing : .ready
        case .androidtv:
            let s = ATVSession()
            s.onPower = { [weak self] on in self?.isOn = on }
            s.onVolume = { [weak self] l, m, muted in self?.volume = Volume(level: l, max: m, muted: muted) }
            s.onClose = { [weak self] _ in
                guard let self = self, self.atv === s else { return }
                self.atv = nil
                if self.phase == .ready { self.phase = .idle }      // beim nächsten Tastendruck neu verbinden
            }
            do {
                try await s.connect(host: d.host)
                guard device?.id == d.id else { s.close(); return }
                atv = s
                RemoteSecrets.setAtvPaired(d.id, true)
                phase = .ready
            } catch {
                phase = RemoteSecrets.atvPaired(d.id)
                    ? .failed("Keine Verbindung zum \(d.name). Ist er an und im selben WLAN? Klappt es dauerhaft nicht, neu koppeln.")
                    : .needsPairing
            }
        }
    }

    func press(_ key: RemoteKey) {
        guard let d = device else { return }
        switch d.kind {
        case .philips:
            guard let tv = philips else { Task { await connect() }; return }
            Task {
                do { try await tv.send(key) }
                catch RemoteError.needsPairing { phase = .needsPairing }
                catch { phase = .failed((error as? LocalizedError)?.errorDescription ?? "Taste nicht angekommen.") }
            }
        case .androidtv:
            if let s = atv { s.press(key); return }
            Task {
                await connect()
                atv?.press(key)
            }
        }
    }

    func send(text: String) { atv?.send(text: text) }

    /// Nach erfolgreicher Kopplung: Daten merken und verbinden
    func paired(_ d: RemoteDevice, philips creds: (String, String)? = nil) {
        if let c = creds { RemoteSecrets.setPhilips(d.id, c) }
        if d.kind == .androidtv { RemoteSecrets.setAtvPaired(d.id, true) }
        close(); open(d)
    }

    /// Kopplung auf diesem Gerät vergessen
    static func forget(_ d: RemoteDevice) {
        RemoteSecrets.setPhilips(d.id, nil)
        RemoteSecrets.setAtvPaired(d.id, false)
    }
}

// MARK: Geräte im WLAN finden (Android TV per Bonjour)

final class RemoteFinder: ObservableObject {
    struct Found: Identifiable, Equatable { let name: String; let host: String; var id: String { host } }

    @Published private(set) var found: [Found] = []
    @Published private(set) var searching = false
    private var browser: NWBrowser?
    private var resolving: [NWConnection] = []

    func start() {
        stop()
        searching = true
        let b = NWBrowser(for: .bonjour(type: "_androidtvremote2._tcp", domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async { results.forEach { self?.resolve($0.endpoint) } }
        }
        b.start(queue: .main)
        browser = b
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.searching = false }
    }

    func stop() {
        browser?.cancel(); browser = nil
        resolving.forEach { $0.cancel() }; resolving = []
        searching = false
    }

    /// Bonjour liefert nur den Namen – für die IP-Adresse kurz eine TCP-Verbindung aufbauen
    private func resolve(_ ep: NWEndpoint) {
        guard case let .service(name, _, _, _) = ep else { return }
        let params = NWParameters.tcp
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options { ip.version = .v4 }   // IPv4-Adresse bevorzugen
        let c = NWConnection(to: ep, using: params)
        resolving.append(c)
        c.stateUpdateHandler = { [weak self] state in
            guard case .ready = state else { return }
            let remote = c.currentPath?.remoteEndpoint
            c.cancel()
            DispatchQueue.main.async {
                guard let self = self, case let .hostPort(host, _)? = remote else { return }
                let ip = "\(host)"
                if !self.found.contains(where: { $0.host == ip }) { self.found.append(Found(name: name, host: ip)) }
            }
        }
        c.start(queue: .main)
    }
}
