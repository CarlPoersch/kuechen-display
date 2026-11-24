import Foundation
import Combine
import SwiftUI   // für move(fromOffsets:toOffset:)
import UIKit

// ============================================================
// Smart Home: Steckdosen des Haushalts (Supabase `smart_devices`) und ihr Zustand.
// Geschaltet und abgefragt wird lokal im WLAN (TuyaLocal), die Tuya-Cloud
// nur bei der Einrichtung bzw. „Geräte neu laden“ (TuyaCloud).
// Zugangsdaten zur Tuya-Cloud liegen nur im Schlüsselbund dieses Geräts.
// ============================================================

struct SmartOutlet: Codable, Hashable {
    var dp: Int
    var name: String
}

struct SmartDevice: Codable, Identifiable, Equatable {
    var householdId: String
    var id: String
    var name: String
    var localKey: String
    var category: String = ""
    var version: String = ""
    var ip: String = ""
    var outlets: [SmartOutlet] = []
    var position: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, name, category, version, ip, outlets, position
        case householdId = "household_id", localKey = "local_key"
    }

    var tuyaVersion: TuyaVersion? { TuyaVersion(rawValue: version) }
    func key(_ o: SmartOutlet) -> String { id + ":" + String(o.dp) }
}

/// Eine Kachel: ein schaltbarer Ausgang einer Steckdose
struct SmartLight: Identifiable, Hashable {
    let id: String          // Geräte-ID:Datenpunkt
    let deviceId: String
    let dp: Int
    let name: String
}

final class SmartHomeStore: ObservableObject {
    static let shared = SmartHomeStore()

    @Published private(set) var devices: [SmartDevice] = []
    @Published private(set) var state: [String: Bool] = [:]          // Kachel-ID → an/aus
    @Published private(set) var unreachable: Set<String> = []        // Geräte-IDs
    @Published private(set) var busy: Set<String> = []               // Kacheln, die gerade schalten
    @Published private(set) var searching = false
    @Published private(set) var loaded = false
    @Published var message: String?

    private let api = SupabaseClient.shared
    private var household: String?
    private var lastServerLoad = Date.distantPast
    private var lastSearch = Date.distantPast
    private var gates: [String: Task<Void, Never>] = [:]
    private let cacheKey = "smarthome.devices"

    init() {
        if let d = UserDefaults.standard.data(forKey: cacheKey),
           let list = try? JSONDecoder().decode([SmartDevice].self, from: d) {
            devices = list
        }
    }

    var lights: [SmartLight] {
        devices.flatMap { d in d.outlets.map { SmartLight(id: d.key($0), deviceId: d.id, dp: $0.dp, name: $0.name) } }
    }

    func isOn(_ l: SmartLight) -> Bool? { state[l.id] }
    func isReachable(_ l: SmartLight) -> Bool { !unreachable.contains(l.deviceId) }

    // MARK: Laden und Abgleich

    /// Geräteliste vom Server (höchstens jede Minute) und Zustände aus dem WLAN
    func refresh(household hid: String?) async {
        guard let hid = hid, !hid.isEmpty else { return }
        if household != hid || Date().timeIntervalSince(lastServerLoad) > 60 { await loadDevices(hid) }
        await withTaskGroup(of: Void.self) { g in
            for id in devices.map(\.id) { g.addTask { await self.poll(id) } }
        }
        // Fehlt eine Adresse oder antwortet eine Steckdose nicht: im WLAN suchen (höchstens alle 2 Minuten)
        let missing = devices.contains { $0.ip.isEmpty || unreachable.contains($0.id) }
        if missing && Date().timeIntervalSince(lastSearch) > 120 { await locate() }
    }

    func loadDevices(_ hid: String) async {
        household = hid
        do {
            let list: [SmartDevice] = try await api.select("smart_devices", ["household_id": "eq." + hid, "order": "position,name"])
            lastServerLoad = Date()
            // Lokal schon gefundene Adressen nicht durch ältere vom Server ersetzen
            devices = list.map { d in
                var d = d
                if d.ip.isEmpty, let old = devices.first(where: { $0.id == d.id }), !old.ip.isEmpty, old.localKey == d.localKey {
                    d.ip = old.ip
                    if d.version.isEmpty { d.version = old.version }
                }
                return d
            }
            cache()
        } catch {
            // offline: zwischengespeicherte Liste bleibt
        }
        loaded = true
    }

    private func poll(_ id: String) async {
        await exclusive(id) {
            guard let d = self.devices.first(where: { $0.id == id }), !d.ip.isEmpty else { return }
            let dps = d.outlets.map(\.dp)
            do {
                if let v = d.tuyaVersion {
                    let (values, real) = try await TuyaLocal.query(host: d.ip, devId: d.id, key: d.localKey, version: v, dps: dps)
                    self.apply(values, to: d)
                    if real != v { self.update(d.id) { $0.version = real.rawValue } }
                } else if let found = await TuyaLocal.identify(host: d.ip, devId: d.id, key: d.localKey, dps: dps) {
                    self.apply(found.1, to: d)
                    self.update(d.id) { $0.version = found.0.rawValue }
                } else {
                    self.unreachable.insert(id)
                }
            } catch {
                self.unreachable.insert(id)
            }
        }
    }

    private func apply(_ values: [String: Any], to d: SmartDevice) {
        unreachable.remove(d.id)
        for o in d.outlets {
            if let b = values[String(o.dp)] as? Bool { state[d.key(o)] = b }
        }
    }

    // MARK: Schalten

    func toggle(_ l: SmartLight) {
        let target = !(state[l.id] ?? false)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state[l.id] = target          // sofort zeigen, danach bestätigen
        busy.insert(l.id)
        Task {
            await self.send(deviceId: l.deviceId, [String(l.dp): target], revert: [l.id: !target])
            self.busy.remove(l.id)
        }
    }

    func allOff() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        for d in devices {
            let on = d.outlets.filter { state[d.key($0)] != false }
            guard !on.isEmpty else { continue }
            var dps: [String: Any] = [:]
            var revert: [String: Bool] = [:]
            for o in on {
                dps[String(o.dp)] = false
                revert[d.key(o)] = state[d.key(o)] ?? true
                state[d.key(o)] = false
            }
            Task { await self.send(deviceId: d.id, dps, revert: revert) }
        }
    }

    /// Bestimmte Lampen an- oder ausschalten (für Wecker, Timer, Gute Nacht). Unbekannte IDs werden übergangen.
    func switchLights(_ ids: [String], on: Bool) {
        for d in devices {
            let outs = d.outlets.filter { ids.contains(d.key($0)) }
            guard !outs.isEmpty else { continue }
            var dps: [String: Any] = [:]
            var revert: [String: Bool] = [:]
            for o in outs {
                dps[String(o.dp)] = on
                revert[d.key(o)] = state[d.key(o)] ?? !on
                state[d.key(o)] = on
            }
            Task { await self.send(deviceId: d.id, dps, revert: revert) }
        }
    }

    private func send(deviceId: String, _ dps: [String: Any], revert: [String: Bool]) async {
        await exclusive(deviceId) {
            guard let d = self.devices.first(where: { $0.id == deviceId }), !d.ip.isEmpty else {
                self.undo(revert, "Steckdose noch nicht im WLAN gefunden.")
                return
            }
            let v = d.tuyaVersion ?? .v33
            do {
                if let reply = try await TuyaLocal.set(host: d.ip, devId: d.id, key: d.localKey, version: v, dps: dps) {
                    self.apply(reply, to: d)
                } else {
                    self.unreachable.remove(d.id)
                }
            } catch {
                self.unreachable.insert(d.id)
                self.undo(revert, "\(d.name): " + ((error as? LocalizedError)?.errorDescription ?? "nicht erreichbar"))
            }
        }
    }

    private func undo(_ revert: [String: Bool], _ text: String) {
        for (k, v) in revert { state[k] = v }
        message = text
    }

    /// Vorgänge je Steckdose nacheinander (viele erlauben nur eine Verbindung)
    private func exclusive(_ id: String, _ op: @escaping () async -> Void) async {
        let previous = gates[id]
        let t = Task { await previous?.value; await op() }
        gates[id] = t
        await t.value
    }

    // MARK: Im WLAN suchen

    /// Alle Adressen im eigenen Netz prüfen und Steckdosen am Schlüssel erkennen
    func locate() async {
        guard !searching, !devices.isEmpty else { return }
        searching = true
        lastSearch = Date()
        defer { searching = false }

        let hosts = TuyaDiscovery.candidates()
        guard !hosts.isEmpty else { message = "Kein WLAN gefunden. Ist dieses Gerät im WLAN?"; return }
        let open = await TuyaDiscovery.openHosts(hosts)
        guard !open.isEmpty else {
            message = "Keine Steckdose im WLAN gefunden. Sie müssen im selben WLAN sein wie dieses Gerät."
            return
        }

        // Gesucht: Geräte ohne Adresse oder ohne Antwort. Bekannte, funktionierende Adressen bleiben belegt.
        let wanted = devices.filter { $0.ip.isEmpty || unreachable.contains($0.id) }
        var taken = Set(devices.filter { !$0.ip.isEmpty && !unreachable.contains($0.id) }.map(\.ip))
        var preferred: [TuyaVersion] = TuyaVersion.detectOrder
        for d in wanted {
            // Zuerst die zuletzt bekannte Adresse, dann die übrigen offenen
            let order = ([d.ip].filter { open.contains($0) }) + open.filter { $0 != d.ip && !taken.contains($0) }
            var versions: [TuyaVersion] = []
            if let known = d.tuyaVersion { versions.append(known == .v33d ? .v33 : known) }
            versions += preferred.filter { !versions.contains($0) }
            for host in order {
                guard let found = await TuyaLocal.identify(host: host, devId: d.id, key: d.localKey,
                                                           dps: d.outlets.map(\.dp), versions: versions) else { continue }
                let v = found.0, values = found.1
                taken.insert(host)
                update(d.id) { $0.ip = host; $0.version = v.rawValue }
                if let fresh = devices.first(where: { $0.id == d.id }) { apply(values, to: fresh) }
                let base: TuyaVersion = v == .v33d ? .v33 : v
                preferred = [base] + preferred.filter { $0 != base }   // gleiche Bauart zuerst probieren
                break
            }
        }
        let still = devices.filter { $0.ip.isEmpty || unreachable.contains($0.id) }
        if !still.isEmpty {
            message = still.count == 1 ? "\(still[0].name) nicht im WLAN gefunden." : "\(still.count) Steckdosen nicht im WLAN gefunden."
        }
    }

    // MARK: Einrichtung (Tuya-Cloud)

    struct Credentials: Codable { var accessId: String; var secret: String; var region: String }
    private static let keychainService = "com.carlpoersch.HubertNext.tuya"

    static var savedCredentials: Credentials? {
        Keychain.load(service: keychainService).flatMap { try? JSONDecoder().decode(Credentials.self, from: $0) }
    }

    static func forgetCredentials() { Keychain.save(nil, service: keychainService) }

    /// Geräte aus der Tuya-Cloud holen, speichern und im WLAN suchen.
    /// Liefert die Zahl der gefundenen Lampen-Schalter.
    func importFromCloud(accessId: String, secret: String, region: TuyaRegion, household hid: String) async throws -> Int {
        let cloud = TuyaCloud(accessId: accessId, secret: secret, region: region)
        let plugs = try await cloud.plugs()
        guard !plugs.isEmpty else {
            throw TuyaCloudError.message("In deinem Tuya-Projekt ist keine Steckdose. Ist die Smart-Life-App unter „Devices → Link App Account“ verknüpft und die Region richtig?")
        }
        let creds = Credentials(accessId: accessId.trimmingCharacters(in: .whitespacesAndNewlines),
                                secret: secret.trimmingCharacters(in: .whitespacesAndNewlines), region: region.rawValue)
        if let data = try? JSONEncoder().encode(creds) { Keychain.save(data, service: Self.keychainService) }

        await loadDevices(hid)
        var list: [SmartDevice] = []
        for (i, p) in plugs.enumerated() {
            let old = devices.first { $0.id == p.id }
            let outlets: [SmartOutlet] = p.switches.enumerated().map { n, s in
                // In Hubert vergebene Namen bleiben erhalten
                if let keep = old?.outlets.first(where: { $0.dp == s.dp }) { return keep }
                return SmartOutlet(dp: s.dp, name: p.switches.count == 1 ? p.name : "\(p.name) \(n + 1)")
            }
            let sameKey = old?.localKey == p.localKey
            list.append(SmartDevice(householdId: hid, id: p.id, name: p.name, localKey: p.localKey, category: p.category,
                                    version: sameKey ? (old?.version ?? "") : "", ip: old?.ip ?? "",
                                    outlets: outlets, position: old?.position ?? (100 + i)))
        }
        // Nicht mehr vorhandene Steckdosen entfernen
        for gone in devices where !list.contains(where: { $0.id == gone.id }) {
            try? await api.delete("smart_devices", ["household_id": "eq." + hid, "id": "eq." + gone.id])
        }
        try await api.upsert("smart_devices", list)
        devices = list.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
        lastServerLoad = Date()
        cache()
        unreachable = Set(devices.filter { $0.ip.isEmpty }.map(\.id))
        lastSearch = .distantPast
        Task { await self.locate() }
        return devices.reduce(0) { $0 + $1.outlets.count }
    }

    // MARK: Ändern

    func rename(_ l: SmartLight, to name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        update(l.deviceId) { d in
            if let i = d.outlets.firstIndex(where: { $0.dp == l.dp }) { d.outlets[i].name = n }
        }
    }

    func setIP(_ deviceId: String, _ ip: String) {
        update(deviceId) { $0.ip = ip.trimmingCharacters(in: .whitespaces) }
        unreachable.remove(deviceId)
        Task { await self.poll(deviceId) }
    }

    /// Reihenfolge der Kacheln (ganze Steckdosen)
    func move(from: IndexSet, to: Int) {
        var list = devices
        list.move(fromOffsets: from, toOffset: to)
        for i in list.indices { list[i].position = i }
        devices = list
        cache()
        let rows = list
        Task { try? await self.api.upsert("smart_devices", rows) }
    }

    private func update(_ id: String, _ change: (inout SmartDevice) -> Void) {
        guard let i = devices.firstIndex(where: { $0.id == id }) else { return }
        var d = devices[i]
        change(&d)
        guard d != devices[i] else { return }
        devices[i] = d
        cache()
        let row = d
        Task { try? await self.api.upsert("smart_devices", [row]) }
    }

    private func cache() {
        if let d = try? JSONEncoder().encode(devices) { UserDefaults.standard.set(d, forKey: cacheKey) }
    }
}
