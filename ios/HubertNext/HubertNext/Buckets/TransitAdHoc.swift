import SwiftUI
import Combine
import CoreLocation
import MapKit

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
    /// Letzte bekannte Position ohne neue Abfrage (für den Start der Karte)
    var lastKnown: CLLocation? { manager.location }

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
    @State private var showMap = false

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }
    private var homeCoord: CLLocationCoordinate2D? {
        guard let h = TransitBucket.home(config), let a = h.loc.lat, let b = h.loc.lon else { return nil }
        return CLLocationCoordinate2D(latitude: a, longitude: b)
    }

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
                if query.count < 3 {
                    Section {
                        Button { showMap = true } label: {
                            Label("Auf der Karte wählen", systemImage: "map").foregroundColor(Theme.accent)
                        }
                    } footer: {
                        Text("Wenn du die genaue Adresse nicht weißt – Nadel auf den Ort schieben.")
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
            .sheet(isPresented: $showMap) {
                MapPickerSheet(start: homeCoord) { p in
                    if isFrom { adhoc.setFrom(p, bucket: bucketId) } else { adhoc.setTo(p, bucket: bucketId) }
                    dismiss()
                }
            }
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

// MARK: Ort auf der Karte wählen

/// Karte mit Stecknadel in der Mitte: verschieben, bis die Nadel richtig sitzt, dann „Diesen Ort wählen“.
/// Warum Nadel in der Mitte statt Antippen: Die Karte von iOS 15 meldet keine Tipp-Position.
struct MapPickerSheet: View {
    var start: CLLocationCoordinate2D? = nil
    let onPick: (TransitBucket.Place) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    @State private var address: String?
    @State private var lastLookup: CLLocation?
    @State private var looking = false
    private let geocoder = CLGeocoder()

    init(start: CLLocationCoordinate2D? = nil, onPick: @escaping (TransitBucket.Place) -> Void) {
        self.start = start
        self.onPick = onPick
        // Start: eigener Standort, sonst übergebener Ort (z. B. Zuhause), sonst Regensburg
        let c = LocationProvider.shared.lastKnown?.coordinate ?? start ?? CLLocationCoordinate2D(latitude: 49.0134, longitude: 12.1016)
        _region = State(initialValue: MKCoordinateRegion(center: c, latitudinalMeters: 1200, longitudinalMeters: 1200))
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region, showsUserLocation: true)
                    .ignoresSafeArea(edges: .bottom)
                // Nadel: Spitze genau in der Kartenmitte
                Image(systemName: "mappin")
                    .font(.system(size: 40, weight: .semibold)).foregroundColor(Theme.accent)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                    .offset(y: -20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill").font(.title2).foregroundColor(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(address ?? (looking ? "Suche Adresse …" : "Karte verschieben"))
                                .font(.headline).lineLimit(2)
                            Text("Nadel auf den gewünschten Ort schieben").font(.caption).foregroundColor(Theme.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    Button {
                        let c = region.center
                        let id = String(format: "%.6f:%.6f:WGS84[dd.ddddd]", c.longitude, c.latitude)
                        onPick(TransitBucket.Place(id: id, name: address ?? "Ort auf der Karte", stop: false, lat: c.latitude, lon: c.longitude))
                        dismiss()
                    } label: {
                        Text("Diesen Ort wählen").font(.body.weight(.semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.regularMaterial))
                .padding(12)
            }
            .navigationTitle("Ort auf der Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            if let l = await LocationProvider.shared.current() {
                                withAnimation { region.center = l.coordinate }
                            }
                        }
                    } label: { Image(systemName: "location") }
                    .accessibilityLabel("Zu meinem Standort")
                }
            }
            // Adresse zur Kartenmitte nachschlagen, sobald die Karte kurz stillsteht
            .onReceive(Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()) { _ in lookup() }
        }
        .navigationViewStyle(.stack)
    }

    private func lookup() {
        let here = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        if let last = lastLookup, last.distance(from: here) < 20 { return }
        guard !looking else { return }
        lastLookup = here
        looking = true
        geocoder.reverseGeocodeLocation(here, preferredLocale: Locale(identifier: "de_DE")) { marks, _ in
            DispatchQueue.main.async {
                looking = false
                guard let m = marks?.first else { address = nil; return }
                let street = [m.thoroughfare, m.subThoroughfare].compactMap { $0 }.joined(separator: " ")
                let parts = [street.isEmpty ? m.name : street, m.locality].compactMap { $0 }.filter { !$0.isEmpty }
                address = parts.isEmpty ? nil : parts.joined(separator: ", ")
            }
        }
    }
}
