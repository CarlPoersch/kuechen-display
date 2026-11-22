import SwiftUI
import Combine

/// Zentraler Zustand der App: Anmeldung, Profil, Haushalt, Buckets.
/// Warum ein Ort für alles: Startseite, Onboarding und Einstellungen sehen immer denselben Stand.
final class AppStore: ObservableObject {
    enum Phase { case loading, signedOut, onboarding, ready }

    @Published var phase: Phase = .loading
    @Published var profile: Profile?
    @Published var household: Household?
    @Published var buckets: [BucketInstance] = []
    @Published var errorMessage: String?

    private let api = SupabaseClient.shared
    private let cacheKey = "hubert.cache.v1"

    // MARK: Ansicht pro Gerät
    // Welche Buckets es gibt und wie sie eingestellt sind, ist auf allen Geräten gleich (Server).
    // Reihenfolge und Größe der Karten gelten nur für dieses Gerät – iPhone und iPad
    // haben so jedes seine eigene Startseite. Der Server behält die Werte von vor dieser
    // Trennung; ein neues Gerät startet mit ihnen.
    // Dazu: welche Buckets auf diesem Gerät ausgeblendet sind (z. B. Sport nur auf dem iPhone).
    private struct Layout: Codable { var order: [String] = []; var sizes: [String: BucketSize] = [:]; var hidden: [String]? }
    private struct ServerSpot { let position: Int; let size: BucketSize }
    private let layoutKey = "hubert.layout.v1"
    private var layout: Layout?
    private var serverSpots: [String: ServerSpot] = [:]

    /// Auf diesem Gerät ausgeblendete Buckets – auf den anderen Geräten weiter sichtbar
    @Published private(set) var hiddenHere: Set<String> = []
    var visibleBuckets: [BucketInstance] { buckets.filter { !hiddenHere.contains($0.id) } }
    static var deviceName: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

    func setHidden(_ id: String, _ hide: Bool) {
        if hide { hiddenHere.insert(id) } else { hiddenHere.remove(id) }
        storeLayout()
    }

    private func loadLayout() {
        guard layout == nil, let d = UserDefaults.standard.data(forKey: layoutKey) else { return }
        layout = try? JSONDecoder().decode(Layout.self, from: d)
        hiddenHere = Set(layout?.hidden ?? [])
    }

    /// Ansicht dieses Geräts merken (Reihenfolge und Größen wie gerade angezeigt)
    private func storeLayout() {
        var l = Layout()
        for b in buckets { l.order.append(b.id); l.sizes[b.id] = b.size }
        let ids = Set(buckets.map { $0.id })
        let hidden = hiddenHere.filter { ids.contains($0) || buckets.isEmpty }
        l.hidden = hidden.isEmpty ? nil : Array(hidden)
        layout = l
        if let d = try? JSONEncoder().encode(l) { UserDefaults.standard.set(d, forKey: layoutKey) }
    }

    /// Server-Liste in der Ansicht dieses Geräts: eigene Reihenfolge und Größen;
    /// auf einem anderen Gerät neu hinzugefügte Buckets kommen hinten dazu.
    private func applyLayout(_ list: [BucketInstance]) -> [BucketInstance] {
        guard let l = layout else { return list }
        var rank: [String: Int] = [:]
        for (i, id) in l.order.enumerated() where rank[id] == nil { rank[id] = i }
        var known: [BucketInstance] = [], added: [BucketInstance] = []
        for var b in list {
            if let s = l.sizes[b.id] { b.size = s }
            if rank[b.id] != nil { known.append(b) } else { added.append(b) }
        }
        known.sort { (rank[$0.id] ?? 0) < (rank[$1.id] ?? 0) }
        return known + added
    }

    private struct Cache: Codable { var profile: Profile?; var household: Household?; var buckets: [BucketInstance] }

    // MARK: Start

    func start() async {
        guard api.session != nil else { phase = .signedOut; return }
        loadLayout()
        restoreCache()
        await reload()
    }

    /// Alles vom Server holen. Ohne Netz bleibt der gespeicherte Stand stehen.
    func reload() async {
        guard let uid = api.userId else { phase = .signedOut; return }
        do {
            let profiles: [Profile] = try await api.select("profiles", ["id": "eq." + uid])
            profile = profiles.first ?? Profile(id: uid, name: nil, interests: [], onboarded: false)
            let homes: [Household] = try await api.rpc("my_household")
            household = homes.first
            let fromServer: [BucketInstance] = try await api.select("user_buckets", ["order": "position"])
            serverSpots = [:]
            for b in fromServer { serverSpots[b.id] = ServerSpot(position: b.position, size: b.size) }
            loadLayout()
            buckets = applyLayout(fromServer)
            if layout == nil { storeLayout() }   // erster Start mit eigener Ansicht: so, wie es gerade aussieht
            saveCache()
            phase = (profile?.onboarded == true && household != nil) ? .ready : .onboarding
        } catch let e as APIError where e.isAuth {
            signOut()
        } catch {
            // Offline: mit gespeichertem Stand weitermachen, wenn es einen gibt
            if profile?.onboarded == true { phase = .ready } else { errorMessage = error.localizedDescription; phase = .onboarding }
        }
    }

    // MARK: Anmeldung

    func signedIn(name: String?) async {
        await reload()
        if let name = name, !name.isEmpty, profile?.name == nil, let uid = api.userId {
            try? await api.update("profiles", ["id": "eq." + uid], ["name": name])
            profile?.name = name
        }
    }

    func signOut() {
        api.signOut()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: layoutKey)
        layout = nil; serverSpots = [:]; hiddenHere = []
        profile = nil; household = nil; buckets = []
        KitchenStore.shared.reset(); CookSession.shared.end(local: true); LiveSync.shared.stop()   // Küchendaten des Haushalts nicht auf dem Gerät lassen
        phase = .signedOut
    }

    /// Konto endgültig löschen (Server), danach abmelden.
    /// Ist man das letzte Mitglied eines Haushalts, wird auch dessen Küche gelöscht.
    func deleteAccount() async throws {
        _ = try await api.raw("POST", "/rest/v1/rpc/delete_my_account", body: Data("{}".utf8))
        signOut()
    }

    /// Ist man das einzige Mitglied im Haushalt? (für den Hinweis beim Löschen)
    func isLastMember() async -> Bool {
        guard let h = household else { return true }
        struct M: Decodable { let user_id: String }
        let members: [M] = (try? await api.select("household_members", ["household_id": "eq." + h.id])) ?? []
        return members.count <= 1
    }

    // MARK: Haushalt

    /// Wie viele Personen im Haushalt sind (für die Anzeige in den Einstellungen)
    func memberCount() async -> Int? {
        guard let h = household else { return nil }
        struct M: Decodable { let user_id: String }
        let members: [M]? = try? await api.select("household_members", ["household_id": "eq." + h.id])
        return members?.count
    }

    func createHousehold(name: String) async throws {
        household = try await api.rpc("create_household", ["p_name": name])
        saveCache()
    }

    func joinHousehold(code: String) async throws {
        household = try await api.rpc("join_household", ["p_code": code])
        saveCache()
    }

    func renameHousehold(_ name: String) async {
        guard let h = household, !name.isEmpty else { return }
        household?.name = name
        try? await api.update("households", ["id": "eq." + h.id], ["name": name])
        saveCache()
    }

    // MARK: Profil

    func saveInterests(_ ids: [String]) async {
        profile?.interests = ids
        guard let uid = api.userId else { return }
        try? await api.update("profiles", ["id": "eq." + uid], ["interests": ids])
    }

    func finishOnboarding(with chosen: [BucketInstance]) async throws {
        buckets = chosen.enumerated().map { pair in var b = pair.element; b.position = pair.offset; return b }
        storeLayout()
        try await saveBucketsThrowing()
        guard let uid = api.userId else { return }
        try await api.update("profiles", ["id": "eq." + uid], ["onboarded": true])
        profile?.onboarded = true
        NewBuckets.markSeen(NewBuckets.ids)   // neue Nutzer kennen den Katalog schon
        saveCache()
        phase = .ready
    }

    // MARK: Buckets

    func addBucket(_ kind: BucketKind, config: [String: JSON]? = nil) {
        buckets.append(BucketInstance(kind: kind.id, position: buckets.count, size: kind.defaultSize,
                                      config: config ?? kind.defaultConfig))
        saveBuckets()
    }

    func removeBucket(id: String) {
        buckets.removeAll { $0.id == id }
        saveBuckets()
    }

    func moveBuckets(from: IndexSet, to: Int) {
        buckets.move(fromOffsets: from, toOffset: to)
        saveBuckets()
    }

    /// Beim Verschieben auf der Startseite: Bucket `id` an die Stelle von `target` setzen.
    /// Speichert noch nicht – erst beim Loslassen (saveBuckets), sonst gäbe es pro Zwischenschritt einen Aufruf.
    func moveBucket(_ id: String, to target: String) {
        guard id != target, let from = buckets.firstIndex(where: { $0.id == id }),
              let to = buckets.firstIndex(where: { $0.id == target }) else { return }
        let item = buckets.remove(at: from)
        buckets.insert(item, at: to)
    }

    /// Einstellungen eines Buckets direkt ändern (z. B. Auswahl in der Karte) und speichern
    func updateConfig(_ id: String, _ change: (inout [String: JSON]) -> Void) {
        guard let i = buckets.firstIndex(where: { $0.id == id }) else { return }
        change(&buckets[i].config)
        saveBuckets()
    }

    /// Speichern im Hintergrund (Änderungen sind lokal sofort sichtbar)
    func saveBuckets() {
        storeLayout()
        saveCache()
        Task { do { try await saveBucketsThrowing() } catch { errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)" } }
    }

    private struct BucketRow: Encodable {
        let id: String; let bucket: String; let position: Int; let size: String; let config: [String: JSON]
    }

    private func saveBucketsThrowing() async throws {
        guard let uid = api.userId else { return }
        for i in buckets.indices { buckets[i].position = i }
        // Reihenfolge und Größe bleiben auf dem Server, wie sie waren (Ansicht ist Sache des Geräts);
        // neue Buckets kommen dort hinten dazu
        var next = (serverSpots.values.map { $0.position }.max() ?? -1) + 1
        var rows: [BucketRow] = []
        for b in buckets {
            let spot: ServerSpot
            if let s = serverSpots[b.id] { spot = s } else { spot = ServerSpot(position: next, size: b.size); next += 1 }
            rows.append(BucketRow(id: b.id, bucket: b.bucket, position: spot.position, size: spot.size.rawValue, config: b.config))
        }
        if !rows.isEmpty { try await api.upsert("user_buckets", rows) }
        for r in rows { serverSpots[r.id] = ServerSpot(position: r.position, size: BucketSize(rawValue: r.size) ?? .m) }
        // Entfernte Buckets auch auf dem Server löschen
        var filter = ["user_id": "eq." + uid]
        if !rows.isEmpty { filter["id"] = "not.in.(" + rows.map { $0.id }.joined(separator: ",") + ")" }
        try await api.delete("user_buckets", filter)
    }

    // MARK: Zwischenspeicher auf dem Gerät

    private func saveCache() {
        let c = Cache(profile: profile, household: household, buckets: buckets)
        if let d = try? JSONEncoder().encode(c) { UserDefaults.standard.set(d, forKey: cacheKey) }
    }

    private func restoreCache() {
        guard let d = UserDefaults.standard.data(forKey: cacheKey),
              let c = try? JSONDecoder().decode(Cache.self, from: d) else { return }
        profile = c.profile; household = c.household; buckets = c.buckets
        if c.profile?.onboarded == true && c.household != nil { phase = .ready }
    }
}
