import SwiftUI
import Combine
import MapKit

// ============================================================
// „Wo ist der Bus?“ – eine Fahrt antippen: Karte mit allen Haltestellen
// der Linie und der ungefähren Position des Busses, darunter der Verlauf
// mit Echtzeit. Position = zwischen der letzten und der nächsten Haltestelle,
// anteilig nach den (Echtzeit-)Zeiten. Ein GPS-Signal liefert die Auskunft nicht.
// Quelle: XML_STOPSEQCOORD_REQUEST (Linienverlauf einer Fahrt) über „efa“.
// ============================================================

struct RideStop: Identifiable, Equatable {
    let id: Int
    let name: String
    let stopId: String?
    let lat: Double?
    let lon: Double?
    let arr: Date?          // Ankunft (Echtzeit, sonst Plan)
    let dep: Date?          // Abfahrt (Echtzeit, sonst Plan)
    let planned: Date?      // geplant (für die Verspätung)
    let live: Bool
    var time: Date? { dep ?? arr }
    var coord: CLLocationCoordinate2D? { lat.flatMap { a in lon.map { CLLocationCoordinate2D(latitude: a, longitude: $0) } } }
    var delay: Int { guard let t = time, let p = planned else { return 0 }; return Int((t.timeIntervalSince(p) / 60).rounded()) }
}

/// Wo der Bus gerade ist
struct RidePosition: Equatable {
    enum Phase: Equatable { case before, at(Int), between(Int, Double), done }
    let phase: Phase
    let coord: CLLocationCoordinate2D?
    static func == (a: RidePosition, b: RidePosition) -> Bool { a.phase == b.phase }

    static func at(_ stops: [RideStop], now: Date = Date()) -> RidePosition {
        guard let first = stops.first else { return RidePosition(phase: .before, coord: nil) }
        if let t = first.dep ?? first.arr, now < t { return RidePosition(phase: .before, coord: first.coord) }
        for i in stops.indices {
            let s = stops[i]
            let a = s.arr ?? s.dep, d = s.dep ?? s.arr
            if let a = a, let d = d, now >= a, now <= d { return RidePosition(phase: .at(i), coord: s.coord) }
            if i + 1 < stops.count, let d = d, let nextA = stops[i + 1].arr ?? stops[i + 1].dep, now > d, now < nextA {
                let f = max(0, min(1, now.timeIntervalSince(d) / max(1, nextA.timeIntervalSince(d))))
                var c = s.coord
                if let p = s.coord, let q = stops[i + 1].coord {
                    c = CLLocationCoordinate2D(latitude: p.latitude + (q.latitude - p.latitude) * f,
                                               longitude: p.longitude + (q.longitude - p.longitude) * f)
                }
                return RidePosition(phase: .between(i, f), coord: c)
            }
        }
        return RidePosition(phase: .done, coord: stops.last?.coord)
    }
}

private struct SeqResponse: Decodable {
    struct P: Decodable { let stopId: String? }
    struct Parent: Decodable { let name: String?; let properties: P? }
    struct Stop: Decodable {
        let name: String?; let parent: Parent?; let coord: [Double]?; let properties: P?
        let arrivalTimePlanned: String?; let arrivalTimeEstimated: String?
        let departureTimePlanned: String?; let departureTimeEstimated: String?
    }
    struct Leg: Decodable { let stopSequence: [Stop]? }
    let leg: Leg?
}

@MainActor
final class RideModel: ObservableObject {
    let ref: RideRef
    @Published private(set) var stops: [RideStop] = []
    @Published private(set) var failed = false
    @Published private(set) var loadedAt: Date?

    init(ref: RideRef) { self.ref = ref }

    var live: Bool { stops.contains { $0.live } }
    var myIndex: Int? { stops.firstIndex { $0.stopId == ref.stop } ?? stops.firstIndex { shortStop($0.name) == shortStop(ref.stopName) } }

    func load() async {
        let tz = TimeZone(identifier: "Europe/Berlin") ?? .current
        let d = DateFormatter(); d.timeZone = tz; d.dateFormat = "yyyyMMdd"
        let t = DateFormatter(); t.timeZone = tz; t.dateFormat = "HHmm"
        let q: [(String, String)] = [
            ("outputFormat", "rapidJSON"), ("coordOutputFormat", "WGS84[dd.ddddd]"),
            ("line", ref.lineId), ("stop", ref.stop), ("tripCode", ref.trip),
            ("date", d.string(from: ref.planned)), ("time", t.string(from: ref.planned)),
            ("useRealtime", "1"), ("tStOTType", "ALL"),   // ALL = ganzer Verlauf ab Starthaltestelle der Linie
        ]
        do {
            let data = try await SupabaseClient.shared.raw("GET", "/functions/v1/efa/XML_STOPSEQCOORD_REQUEST",
                                                           query: q.map { URLQueryItem(name: $0.0, value: $0.1) })
            let r = try JSONDecoder().decode(SeqResponse.self, from: data)
            var list: [RideStop] = []
            for s in r.leg?.stopSequence ?? [] {
                let arrE = Fmt.date(s.arrivalTimeEstimated), depE = Fmt.date(s.departureTimeEstimated)
                let arr = arrE ?? Fmt.date(s.arrivalTimePlanned), dep = depE ?? Fmt.date(s.departureTimePlanned)
                list.append(RideStop(id: list.count, name: s.parent?.name ?? s.name ?? "", stopId: s.parent?.properties?.stopId ?? s.properties?.stopId,
                                     lat: s.coord?.first, lon: (s.coord?.count ?? 0) > 1 ? s.coord?[1] : nil,
                                     arr: arr, dep: dep, planned: Fmt.date(s.departureTimePlanned) ?? Fmt.date(s.arrivalTimePlanned),
                                     live: arrE != nil || depE != nil))
            }
            if !list.isEmpty { stops = list; failed = false } else if stops.isEmpty { failed = true }
            loadedAt = Date()
        } catch {
            if stops.isEmpty { failed = true }
            print("ÖPNV Fahrtverlauf:", error)
        }
    }
}

/// Blatt: Fahrt verfolgen
struct RideSheet: View {
    let ref: RideRef
    @StateObject private var model: RideModel
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 49.0134, longitude: 12.1016),
                                                   span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06))
    @State private var fitted = false

    init(ref: RideRef) {
        self.ref = ref
        _model = StateObject(wrappedValue: RideModel(ref: ref))
    }

    private struct Pin: Identifiable {
        enum Kind { case stop, past, mine, bus }
        let id: String
        let coord: CLLocationCoordinate2D
        let kind: Kind
    }

    var body: some View {
        NavigationView {
            TimelineView(.periodic(from: .now, by: 5)) { ctx in
                let pos = RidePosition.at(model.stops, now: ctx.date)
                ScrollViewReader { reader in
                    List {
                        Section { mapView(pos).listRowInsets(EdgeInsets()) }
                        Section { status(pos, now: ctx.date) }
                        if model.stops.isEmpty {
                            Section {
                                if model.failed { Text("Verlauf dieser Fahrt gerade nicht verfügbar").foregroundColor(Theme.secondary) }
                                else { HStack(spacing: 10) { ProgressView(); Text("Lädt Verlauf …").foregroundColor(Theme.secondary) } }
                            }
                        } else {
                            Section(header: Text("Verlauf"), footer: Text(model.live
                                    ? "Zeiten mit Echtzeit. Die Position ist aus den Zeiten geschätzt, nicht per GPS."
                                    : "Für diese Fahrt gibt es gerade keine Echtzeit – Position nach Fahrplan.")) {
                                ForEach(model.stops) { s in stopRow(s, pos: pos).id(s.id) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .onChange(of: model.loadedAt) { _ in
                        // Beim ersten Laden zum Bus springen
                        if !fitted, let i = busIndex(pos) { reader.scrollTo(max(0, i - 1), anchor: .top) }
                        fit(pos)
                    }
                }
            }
            .navigationTitle("Linie " + ref.line)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        // Alle 20 Sek. neue Echtzeit holen, solange das Blatt offen ist
        .task {
            while !Task.isCancelled {
                await model.load()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }

    // MARK: Karte

    private func pins(_ pos: RidePosition) -> [Pin] {
        var out: [Pin] = []
        let passed = passedIndex(pos)
        for s in model.stops {
            guard let c = s.coord else { continue }
            out.append(Pin(id: "s\(s.id)", coord: c, kind: s.id == model.myIndex ? .mine : s.id <= passed ? .past : .stop))
        }
        if let c = pos.coord, pos.phase != .done { out.append(Pin(id: "bus", coord: c, kind: .bus)) }
        return out
    }

    private func mapView(_ pos: RidePosition) -> some View {
        Map(coordinateRegion: $region, annotationItems: pins(pos)) { p in
            MapAnnotation(coordinate: p.coord) {
                switch p.kind {
                case .bus:
                    Image(systemName: "bus.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(lineColor(ref.line)))
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                case .mine:
                    Circle().fill(Theme.accent).frame(width: 14, height: 14).overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                case .stop:
                    Circle().fill(Color.white).frame(width: 9, height: 9).overlay(Circle().stroke(lineColor(ref.line), lineWidth: 2.5))
                case .past:
                    Circle().fill(Color.gray.opacity(0.6)).frame(width: 7, height: 7)
                }
            }
        }
        .frame(height: 260)
        .overlay(alignment: .bottomTrailing) {
            Button { fit(pos, force: true) } label: {
                Image(systemName: "scope").font(.body.weight(.semibold)).foregroundColor(Theme.accent)
                    .frame(width: 40, height: 40).background(Circle().fill(.regularMaterial))
            }
            .padding(10)
            .accessibilityLabel("Zum Bus")
        }
    }

    /// Ausschnitt: Bus und eigene Haltestelle, sonst die ganze Linie
    private func fit(_ pos: RidePosition, force: Bool = false) {
        guard force || !fitted else { return }
        var pts = [pos.coord, model.myIndex.flatMap { model.stops[$0].coord }].compactMap { $0 }
        if pts.count < 2 { pts = model.stops.compactMap { $0.coord } }
        guard let first = pts.first else { return }
        var minLat = first.latitude, maxLat = first.latitude, minLon = first.longitude, maxLon = first.longitude
        for p in pts { minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude); minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude) }
        let r = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                                   span: MKCoordinateSpan(latitudeDelta: max(0.008, (maxLat - minLat) * 1.6),
                                                          longitudeDelta: max(0.008, (maxLon - minLon) * 1.6)))
        withAnimation { region = r }
        fitted = true
    }

    // MARK: Status

    private func status(_ pos: RidePosition, now: Date) -> some View {
        let s = model.stops
        var title = "Richtung " + shortStop(ref.toward)
        switch pos.phase {
        case .before: if let f = s.first { title = "Startet " + Fmt.hhmm(f.time ?? now) + " an " + shortStop(f.name) }
        case .at(let i): title = "Steht an " + shortStop(s[i].name)
        case .between(let i, _): title = "Zwischen " + shortStop(s[i].name) + " und " + shortStop(s[i + 1].name)
        case .done: title = "Fahrt beendet"
        }
        var sub = ""
        if let m = model.myIndex, let t = s[m].arr ?? s[m].dep {
            let mins = Int((t.timeIntervalSince(now) / 60).rounded())
            if passedIndex(pos) >= m { sub = "Schon an " + shortStop(s[m].name) + " vorbei" }
            else { sub = mins <= 0 ? "Jetzt an " + shortStop(s[m].name) : "In \(mins) min an " + shortStop(s[m].name) + " (" + Fmt.hhmm(t) + ")" }
        }
        let delay = model.myIndex.map { s[$0].delay } ?? s.first(where: { $0.live })?.delay ?? 0
        return HStack(spacing: 12) {
            LineBadge(line: ref.line)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).lineLimit(2)
                if !sub.isEmpty { Text(sub).font(.subheadline).foregroundColor(Theme.secondary) }
                HStack(spacing: 6) {
                    Circle().fill(model.live ? Color.green : Color.gray).frame(width: 7, height: 7)
                    Text(model.live ? (delay > 0 ? "Live · \(delay) min später" : "Live · pünktlich") : "Fahrplan")
                        .font(.caption.weight(.semibold)).foregroundColor(model.live && delay > 0 ? .red : Theme.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: Verlauf

    /// Index der letzten Haltestelle, an der der Bus schon war
    private func passedIndex(_ pos: RidePosition) -> Int {
        switch pos.phase {
        case .before: return -1
        case .at(let i): return i - 1
        case .between(let i, _): return i
        case .done: return model.stops.count
        }
    }
    private func busIndex(_ pos: RidePosition) -> Int? {
        switch pos.phase { case .at(let i), .between(let i, _): return i; default: return nil }
    }

    private func stopRow(_ s: RideStop, pos: RidePosition) -> some View {
        let passed = s.id <= passedIndex(pos)
        let here: Bool = { if case .at(let i) = pos.phase { return i == s.id }; return false }()
        let after: Bool = { if case .between(let i, _) = pos.phase { return i == s.id }; return false }()
        let mine = s.id == model.myIndex
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(here ? lineColor(ref.line) : passed ? Color.gray.opacity(0.5) : Color(UIColor.systemBackground))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(passed ? Color.clear : lineColor(ref.line), lineWidth: 2.5))
                }
                .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(shortStop(s.name)).font(mine ? .body.weight(.semibold) : .body)
                        .foregroundColor(passed ? Theme.secondary : .primary).lineLimit(1)
                    if mine { Text("Dein Einstieg").font(.caption.weight(.semibold)).foregroundColor(Theme.accent) }
                    if here { Text("Bus ist hier").font(.caption.weight(.semibold)).foregroundColor(lineColor(ref.line)) }
                }
                Spacer(minLength: 4)
                if let t = s.time {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Fmt.hhmm(t)).font(.subheadline.monospacedDigit().weight(mine ? .semibold : .regular))
                            .foregroundColor(s.delay > 0 && !passed ? .red : passed ? Theme.secondary : .primary)
                        if s.delay > 0 && !passed, let p = s.planned {
                            Text(Fmt.hhmm(p)).font(.caption2.monospacedDigit()).strikethrough().foregroundColor(Theme.secondary)
                        }
                    }
                }
            }
            // Zwischen zwei Haltestellen: Bus-Zeile darunter
            if after {
                HStack(spacing: 12) {
                    Image(systemName: "bus.fill").font(.caption.weight(.bold)).foregroundColor(.white)
                        .frame(width: 22, height: 22).background(Circle().fill(lineColor(ref.line)))
                    Text("Bus ist unterwegs zur nächsten Haltestelle").font(.caption.weight(.semibold)).foregroundColor(lineColor(ref.line))
                }
            }
        }
        .padding(.vertical, 2)
    }
}
