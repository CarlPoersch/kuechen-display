import SwiftUI
import Combine
import CoreLocation

// ============================================================
// ÖPNV spontan: Start oder Ziel kurz suchen bzw. „Mein Standort“,
// ohne es bei den gespeicherten Zielen abzulegen.
// Gilt nur auf diesem Gerät und läuft nach 3 Stunden ab – danach
// zeigt die Karte wieder die gespeicherte Auswahl.
// ============================================================

final class TransitAdHoc: ObservableObject {
    static let shared = TransitAdHoc()

    struct Pick: Codable, Equatable, Hashable {
        var id: String
        var name: String
        var stop: Bool
        var lat: Double?
        var lon: Double?
        var here = false          // Mein Standort
        var at = Date()

        var place: TransitBucket.Place { TransitBucket.Place(id: id, name: name, stop: stop, lat: lat, lon: lon) }
        init(_ p: TransitBucket.Place) { id = p.id; name = p.name; stop = p.stop; lat = p.lat; lon = p.lon }
        init(hereAt l: CLLocation) {
            let lat = l.coordinate.latitude, lon = l.coordinate.longitude
            // EFA erwartet Koordinaten als „Länge:Breite:Format“
            id = String(format: "%.6f:%.6f:WGS84[dd.ddddd]", lon, lat)
            name = "Mein Standort"; stop = false; self.lat = lat; self.lon = lon; here = true
        }
    }

    private struct Stored: Codable { var from: [String: Pick] = [:]; var to: [String: Pick] = [:]; var recent: [Pick] = [] }
    private let key = "transit.adhoc.v1"
    private let ttl: TimeInterval = 3 * 3600

    @Published private var data = Stored()
    @Published private(set) var locating: Set<String> = []     // Buckets, für die gerade der Standort gesucht wird
    @Published private(set) var locationDenied = false

    init() {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Stored.self, from: d) { data = s }
    }

    private func save() { if let d = try? JSONEncoder().encode(data) { UserDefaults.standard.set(d, forKey: key) } }

    func from(_ bucket: String) -> Pick? { data.from[bucket].flatMap { Date().timeIntervalSince($0.at) < ttl ? $0 : nil } }
    func to(_ bucket: String) -> Pick? { data.to[bucket].flatMap { Date().timeIntervalSince($0.at) < ttl ? $0 : nil } }
    /// Zuletzt gesuchte Orte (ohne Standort), neueste zuerst
    var recent: [Pick] { data.recent }

    func setFrom(_ p: TransitBucket.Place?, bucket: String) {
        data.from[bucket] = p.map { Pick($0) }
        if let p = p { remember(p) }
        save()
    }
    func setTo(_ p: TransitBucket.Place?, bucket: String) {
        data.to[bucket] = p.map { Pick($0) }
        if let p = p { remember(p) }
        save()
    }
    /// Gespeicherte Auswahl gilt wieder (z. B. nach Wahl eines gespeicherten Orts)
    func clear(from: Bool, bucket: String) {
        if from { data.from[bucket] = nil } else { data.to[bucket] = nil }
        save()
    }

    private func remember(_ p: TransitBucket.Place) {
        data.recent.removeAll { $0.id == p.id }
        data.recent.insert(Pick(p), at: 0)
        data.recent = Array(data.recent.prefix(6))
    }

    /// „Mein Standort“ als Start; holt die Position (Erlaubnis wird beim ersten Mal erfragt)
    func useHere(bucket: String) {
        Task { await locate(bucket: bucket) }
    }

    /// Standort auffrischen, wenn er älter als 3 Minuten ist (beim Nachladen der Karte)
    func refreshHere(bucket: String) async {
        guard let p = from(bucket), p.here, Date().timeIntervalSince(p.at) > 180 else { return }
        await locate(bucket: bucket)
    }

    private func locate(bucket: String) async {
        locating.insert(bucket)
        defer { locating.remove(bucket) }
        if let l = await LocationProvider.shared.current() {
            locationDenied = false
            data.from[bucket] = Pick(hereAt: l)
            save()
        } else {
            locationDenied = LocationProvider.shared.denied
        }
    }
}

/// Einmalige Standortabfrage (nur während der Nutzung)
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()
    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<CLLocation?, Never>] = []
    private var round = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var denied: Bool { manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted }

    func current() async -> CLLocation? {
        if let l = manager.location, Date().timeIntervalSince(l.timestamp) < 90 { return l }
        if denied { return nil }
        return await withCheckedContinuation { c in
            waiting.append(c)
            round += 1
            let mine = round
            if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
            else { manager.requestLocation() }
            // Keine Antwort nach 20 Sek. → aufgeben (z. B. kein GPS im Gebäude)
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                if self?.round == mine { self?.finish(nil) }
            }
        }
    }

    private func finish(_ l: CLLocation?) {
        let w = waiting
        waiting = []
        w.forEach { $0.resume(returning: l) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let status = m.authorizationStatus
        DispatchQueue.main.async {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: if !self.waiting.isEmpty { self.manager.requestLocation() }
            case .denied, .restricted: self.finish(nil)
            default: break
            }
        }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        DispatchQueue.main.async { self.finish(last) }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.finish(nil) }
    }
}

/// Blatt: Start oder Ziel spontan suchen. Ergebnis gilt nur für jetzt;
/// mit dem Lesezeichen lässt es sich dauerhaft als Ziel speichern.
struct TransitSearchSheet: View {
    let bucketId: String
    let isFrom: Bool
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var adhoc = TransitAdHoc.shared
    @State private var query = ""
    @State private var results: [TransitBucket.Place] = []
    @State private var searching = false
    @State private var savedIds: Set<String> = []
    @FocusState private var focused: Bool

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
                        TextField("Haltestelle oder Adresse", text: $query)
                            .focused($focused).disableAutocorrection(true).submitLabel(.search)
                        if searching { ProgressView() }
                        else if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Theme.secondary) }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                if isFrom && query.count < 3 {
                    Section {
                        Button {
                            adhoc.useHere(bucket: bucketId); dismiss()
                        } label: {
                            Label("Mein Standort", systemImage: "location.fill").foregroundColor(Theme.accent)
                        }
                    } footer: {
                        Text(adhoc.locationDenied
                             ? "Standortzugriff ist aus – erlauben in Einstellungen › Datenschutz › Ortungsdienste › Hubert."
                             : "Abfahrten in der Nähe oder Verbindungen ab dort, wo du gerade bist.")
                    }
                }
                if query.count >= 3 {
                    Section {
                        if results.isEmpty && !searching {
                            Text("Nichts gefunden").foregroundColor(Theme.secondary)
                        }
                        ForEach(results, id: \.self) { p in row(p) }
                    }
                } else if !adhoc.recent.isEmpty {
                    Section(header: Text("Zuletzt gesucht")) {
                        ForEach(adhoc.recent, id: \.self) { p in row(p.place) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isFrom ? "Start suchen" : "Ziel suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .task(id: query) {
                guard query.count >= 3 else { results = []; return }
                try? await Task.sleep(nanoseconds: 350_000_000)     // erst suchen, wenn kurz nicht getippt wird
                guard !Task.isCancelled else { return }
                searching = true
                results = await TransitService.shared.search(query, stopsOnly: false)
                searching = false
            }
            .onAppear { focused = true }
        }
        .navigationViewStyle(.stack)
    }

    private func row(_ p: TransitBucket.Place) -> some View {
        HStack(spacing: 12) {
            Button {
                if isFrom { adhoc.setFrom(p, bucket: bucketId) } else { adhoc.setTo(p, bucket: bucketId) }
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: p.stop ? "bus.fill" : "mappin.circle.fill").foregroundColor(p.stop ? .blue : .red)
                        .frame(width: 24)
                    Text(p.name).foregroundColor(.primary).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            // Dauerhaft merken: landet bei den gespeicherten Zielen
            let known = savedIds.contains(p.id) || TransitBucket.saved(config).contains { $0.loc.id == p.id }
            Button { save(p) } label: {
                Image(systemName: known ? "bookmark.fill" : "bookmark").foregroundColor(Theme.accent)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .disabled(known)
            .accessibilityLabel(known ? "Gespeichert" : "Als Ziel speichern")
        }
    }

    private func save(_ p: TransitBucket.Place) {
        store.updateConfig(bucketId) { c in
            var list = TransitBucket.saved(c)
            guard !list.contains(where: { $0.loc.id == p.id }) else { return }
            list.append(TransitBucket.Saved(key: UUID().uuidString, label: shortStop(p.name), loc: p))
            TransitBucket.store(list, in: &c)
        }
        savedIds.insert(p.id)
    }
}
