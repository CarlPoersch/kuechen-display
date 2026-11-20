import SwiftUI

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

    private struct Cache: Codable { var profile: Profile?; var household: Household?; var buckets: [BucketInstance] }

    // MARK: Start

    func start() async {
        guard api.session != nil else { phase = .signedOut; return }
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
            buckets = try await api.select("user_buckets", ["order": "position"])
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
        profile = nil; household = nil; buckets = []
        phase = .signedOut
    }

    // MARK: Haushalt

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
        try await saveBucketsThrowing()
        guard let uid = api.userId else { return }
        try await api.update("profiles", ["id": "eq." + uid], ["onboarded": true])
        profile?.onboarded = true
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

    /// Speichern im Hintergrund (Änderungen sind lokal sofort sichtbar)
    func saveBuckets() {
        saveCache()
        Task { do { try await saveBucketsThrowing() } catch { errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)" } }
    }

    private struct BucketRow: Encodable {
        let id: String; let bucket: String; let position: Int; let size: String; let config: [String: JSON]
    }

    private func saveBucketsThrowing() async throws {
        guard let uid = api.userId else { return }
        for i in buckets.indices { buckets[i].position = i }
        let rows = buckets.map { BucketRow(id: $0.id, bucket: $0.bucket, position: $0.position, size: $0.size.rawValue, config: $0.config) }
        if !rows.isEmpty { try await api.upsert("user_buckets", rows) }
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
