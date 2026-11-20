import SwiftUI
import Combine

// ============================================================
// ÖPNV-Bucket. Pro Eintrag ein Startpunkt (Haltestelle oder Adresse)
// und optional ein Ziel:
//  - ohne Ziel: Abfahrtstafel der Start-Haltestelle
//  - mit Ziel:  Verbindungen von Start nach Ziel (mit Umstiegen)
// "Los in" = wann man aus der Tür muss (Abfahrt minus Fußweg).
// Quelle: Bayern-Fahrplanauskunft (EFA) über die Supabase-Funktion "efa".
// Einstellungen: stops = [{ key, from: {id, name, stop}, to?: {id, name, stop}, walk, lines }]
// ============================================================
enum TransitBucket {
    static let kind = BucketKind(
        id: "oepnv", name: "ÖPNV", symbol: "bus.fill", tint: .blue, art: .glance,
        interests: ["unterwegs"], blurb: "Wann du los musst – Abfahrten oder Verbindungen zu deinem Ziel (Bayern).",
        needsSetup: { routes($0).isEmpty },
        glance: { inst, size in AnyView(TransitGlance(routes: routes(inst.config))) },
        detail: { inst in AnyView(TransitDetail(routes: routes(inst.config))) },
        settings: { binding in AnyView(TransitSettings(config: binding)) }
    )

    struct Place: Equatable, Hashable {
        var id: String      // Haltestellen-Nummer oder EFA-Ortskennung (Adresse)
        var name: String
        var stop: Bool
        var json: JSON { .object(["id": .string(id), "name": .string(name), "stop": .bool(stop)]) }
        init(id: String, name: String, stop: Bool) { self.id = id; self.name = name; self.stop = stop }
        init?(_ j: JSON?) {
            guard let o = j?.object, let id = o["id"]?.string, let n = o["name"]?.string else { return nil }
            self.init(id: id, name: n, stop: o["stop"]?.bool ?? true)
        }
    }

    struct Route: Identifiable, Equatable {
        var key: String
        var from: Place
        var to: Place?
        var walk: Int
        var lines: String
        var id: String { key }
        var title: String { to.map { from.name + " → " + $0.name } ?? from.name }

        func accepts(_ d: Departure) -> Bool {
            let wanted = lines.split(whereSeparator: { $0 == "," || $0 == " " }).map { String($0).lowercased() }
            return wanted.isEmpty || wanted.contains(d.line.lowercased())
        }
    }

    static func routes(_ c: [String: JSON]) -> [Route] {
        (c["stops"]?.array ?? []).compactMap { j in
            guard let o = j.object else { return nil }
            let walk = Int(o["walk"]?.double ?? 0), lines = o["lines"]?.string ?? ""
            if let from = Place(o["from"]) {
                return Route(key: o["key"]?.string ?? from.id, from: from, to: Place(o["to"]), walk: walk, lines: lines)
            }
            // Altes Format: nur Haltestelle
            guard let id = o["id"]?.string, let n = o["name"]?.string else { return nil }
            return Route(key: id, from: Place(id: id, name: n, stop: true), to: nil, walk: walk, lines: lines)
        }
    }

    static func store(_ list: [Route], in c: inout [String: JSON]) {
        c["stops"] = .array(list.map { r in
            var o: [String: JSON] = ["key": .string(r.key), "from": r.from.json, "walk": .number(Double(r.walk)), "lines": .string(r.lines)]
            if let t = r.to { o["to"] = t.json }
            return .object(o)
        })
    }
}

// MARK: Daten

struct Departure: Identifiable {
    let id: String
    let line: String
    let dest: String
    let planned: Date
    let actual: Date
    let realtime: Bool
    var delay: Int { Int(actual.timeIntervalSince(planned) / 60) }
}

struct Journey: Identifiable {
    struct Ride: Hashable { let line: String; let from: String; let to: String; let dep: Date; let arr: Date }
    let id: String
    let leave: Date        // wann man losgeht (inkl. Fußweg)
    let depart: Date       // Abfahrt des ersten Fahrzeugs
    let arrive: Date
    let delay: Int         // Verspätung des ersten Fahrzeugs
    let rides: [Ride]
    var changes: Int { max(0, rides.count - 1) }
}

/// Einheitlicher Eintrag für die Startseite
struct TransitItem: Identifiable {
    let id: String
    let line: String
    let leave: Date
    let top: String
    let sub: String
    let delay: Int
}

private struct DMResponse: Decodable {
    struct T: Decodable { let year: String; let month: String; let day: String; let hour: String; let minute: String
        var date: Date? {
            var c = DateComponents(); c.year = Int(year); c.month = Int(month); c.day = Int(day); c.hour = Int(hour); c.minute = Int(minute)
            return Calendar.current.date(from: c)
        }
    }
    struct Line: Decodable { let number: String?; let direction: String?; let key: String? }
    struct D: Decodable { let dateTime: T?; let realDateTime: T?; let servingLine: Line? }
    let departureList: [D]?
}

private struct TripResponse: Decodable {
    struct Point: Decodable {
        let name: String?
        let departureTimePlanned: String?; let departureTimeEstimated: String?
        let arrivalTimePlanned: String?; let arrivalTimeEstimated: String?
        var dep: Date? { Fmt.date(departureTimeEstimated) ?? Fmt.date(departureTimePlanned) }
        var depPlanned: Date? { Fmt.date(departureTimePlanned) }
        var arr: Date? { Fmt.date(arrivalTimeEstimated) ?? Fmt.date(arrivalTimePlanned) }
    }
    struct Transport: Decodable { let number: String? }
    struct Leg: Decodable { let origin: Point; let destination: Point; let transportation: Transport?
        var isRide: Bool { !(transportation?.number ?? "").isEmpty }
    }
    struct J: Decodable { let legs: [Leg] }
    let journeys: [J]?
}

private struct StopFinder: Decodable {
    struct Loc: Decodable {
        struct P: Decodable { let stopId: String? }
        let id: String?; let name: String?; let type: String?; let properties: P?
    }
    let locations: [Loc]?
}

final class TransitService: ObservableObject {
    static let shared = TransitService()
    @Published private(set) var boards: [String: [Departure]] = [:]    // je Haltestelle
    @Published private(set) var trips: [String: [Journey]] = [:]       // je Route
    @Published private(set) var failed: Set<String> = []
    private var loadedAt: [String: Date] = [:]

    private func fresh(_ key: String) -> Bool {
        if let t = loadedAt[key], Date().timeIntervalSince(t) < 45 { return true }
        return false
    }

    func load(_ routes: [TransitBucket.Route]) async {
        for r in routes {
            if r.to != nil { await loadTrips(r) } else if r.from.stop { await loadBoard(r.from.id) }
        }
    }

    private func efa(_ endpoint: String, _ q: [(String, String)]) async throws -> Data {
        try await SupabaseClient.shared.raw("GET", "/functions/v1/efa/" + endpoint, query: q.map { URLQueryItem(name: $0.0, value: $0.1) })
    }

    private func loadBoard(_ id: String) async {
        if fresh("b:" + id) { return }
        do {
            let data = try await efa("XML_DM_REQUEST", [("outputFormat", "JSON"), ("mode", "direct"), ("type_dm", "stop"),
                                                       ("name_dm", id), ("useRealtime", "1"), ("limit", "40")])
            let r = try JSONDecoder().decode(DMResponse.self, from: data)
            boards[id] = (r.departureList ?? []).compactMap { d in
                guard let p = d.dateTime?.date else { return nil }
                let a = d.realDateTime?.date
                return Departure(id: id + (d.servingLine?.key ?? "") + "\(p.timeIntervalSince1970)",
                                 line: d.servingLine?.number ?? "?", dest: d.servingLine?.direction ?? "",
                                 planned: p, actual: a ?? p, realtime: a != nil)
            }.sorted { $0.actual < $1.actual }
            loadedAt["b:" + id] = Date(); failed.remove(id)
        } catch { failed.insert(id); print("ÖPNV:", error) }
    }

    private func loadTrips(_ r: TransitBucket.Route) async {
        guard let to = r.to, !fresh("t:" + r.key) else { return }
        // Ab Haltestelle: frühestens nach dem Fußweg. Ab Adresse rechnet EFA den Fußweg selbst.
        let start = Date().addingTimeInterval(r.from.stop ? Double(r.walk) * 60 : 0)
        let d = DateFormatter(); d.dateFormat = "yyyyMMdd"
        let t = DateFormatter(); t.dateFormat = "HHmm"
        do {
            let data = try await efa("XML_TRIP_REQUEST2", [
                ("outputFormat", "rapidJSON"), ("type_origin", "any"), ("name_origin", r.from.id),
                ("type_destination", "any"), ("name_destination", to.id), ("itdTripDateTimeDepArr", "dep"),
                ("itdDate", d.string(from: start)), ("itdTime", t.string(from: start)),
                ("calcNumberOfTrips", "6"), ("maxChanges", "2"), ("useRealtime", "1"),
            ])
            let resp = try JSONDecoder().decode(TripResponse.self, from: data)
            var out: [Journey] = []
            for j in resp.journeys ?? [] {
                let rides = j.legs.filter { $0.isRide }.compactMap { l -> Journey.Ride? in
                    guard let dep = l.origin.dep, let arr = l.destination.arr else { return nil }
                    return Journey.Ride(line: l.transportation?.number ?? "?", from: l.origin.name ?? "",
                                        to: l.destination.name ?? "", dep: dep, arr: arr)
                }
                guard let first = rides.first, let firstLeg = j.legs.first, let arrive = j.legs.last?.destination.arr,
                      let rideLeg = j.legs.first(where: { $0.isRide }) else { continue }
                // Start an einer Adresse: losgehen, wenn der Fußweg beginnt
                let leave = !firstLeg.isRide && !r.from.stop ? (firstLeg.origin.dep ?? first.dep)
                                                             : first.dep.addingTimeInterval(-Double(r.walk) * 60)
                let delay = (rideLeg.origin.depPlanned).map { Int(first.dep.timeIntervalSince($0) / 60) } ?? 0
                let id = rides.map { $0.line + "\(Int($0.dep.timeIntervalSince1970))" }.joined()
                if out.contains(where: { $0.id == id }) { continue }
                out.append(Journey(id: id, leave: leave, depart: first.dep, arrive: arrive, delay: max(0, delay), rides: rides))
            }
            trips[r.key] = out.sorted { $0.leave < $1.leave }
            loadedAt["t:" + r.key] = Date(); failed.remove(r.key)
        } catch { failed.insert(r.key); print("ÖPNV Verbindung:", error) }
    }

    /// Suche nach Haltestellen und Adressen
    func search(_ text: String, stopsOnly: Bool) async -> [TransitBucket.Place] {
        var q: [(String, String)] = [("outputFormat", "rapidJSON"), ("type_sf", "any"), ("name_sf", text)]
        if stopsOnly { q.append(("anyObjFilter_sf", "2")) }
        guard let data = try? await efa("XML_STOPFINDER_REQUEST", q),
              let r = try? JSONDecoder().decode(StopFinder.self, from: data) else { return [] }
        return (r.locations ?? []).prefix(8).compactMap { l in
            guard let n = l.name else { return nil }
            if l.type == "stop", let sid = l.properties?.stopId { return TransitBucket.Place(id: sid, name: n, stop: true) }
            guard let id = l.id, ["singlehouse", "street", "poi", "suburb"].contains(l.type ?? "") else { return nil }
            return TransitBucket.Place(id: id, name: n, stop: false)
        }
    }

    /// Einträge für die Startseite, nach "Los in" sortiert
    func items(_ routes: [TransitBucket.Route]) -> [TransitItem] {
        let now = Date().addingTimeInterval(-30)
        var out: [TransitItem] = []
        for r in routes {
            if let to = r.to {
                for j in trips[r.key] ?? [] where j.leave > now {
                    out.append(TransitItem(id: r.key + j.id, line: j.rides.first?.line ?? "?", leave: j.leave,
                                           top: "nach " + to.name,
                                           sub: Fmt.hhmm(j.depart) + " → " + Fmt.hhmm(j.arrive) + (j.changes > 0 ? " · \(j.changes)× umsteigen" : " · direkt"),
                                           delay: j.delay))
                }
            } else {
                for d in (boards[r.from.id] ?? []) where r.accepts(d) {
                    let leave = d.actual.addingTimeInterval(-Double(r.walk) * 60)
                    if leave > now {
                        out.append(TransitItem(id: r.key + d.id, line: d.line, leave: leave, top: d.dest,
                                               sub: Fmt.hhmm(d.actual) + " ab " + r.from.name, delay: d.delay))
                    }
                }
            }
        }
        return out.sorted { $0.leave < $1.leave }
    }
}

private func leaveText(_ leave: Date) -> String {
    let m = Int(leave.timeIntervalSinceNow / 60)
    return m <= 0 ? "jetzt los" : "in \(m) min"
}

// MARK: Ansichten

struct LineBadge: View {
    let line: String
    var body: some View {
        Text(line).font(.subheadline.weight(.bold).monospacedDigit()).foregroundColor(.white).lineLimit(1)
            .frame(minWidth: 34).padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.blue))
    }
}

struct TransitGlance: View {
    let routes: [TransitBucket.Route]
    @ObservedObject private var svc = TransitService.shared
    @Environment(\.glanceSpace) private var space

    var body: some View {
        content.refreshing(id: routes.map { $0.key + ($0.to?.id ?? "") + "\($0.walk)" }.joined(), every: { 60 }) {
            await TransitService.shared.load(routes)
        }
    }

    @ViewBuilder private var content: some View {
        let list = Array(svc.items(routes).prefix(fitRows(space.height, row: 50)))
        if routes.isEmpty {
            Text("Startpunkt in den Einstellungen wählen").foregroundColor(Theme.secondary)
        } else if list.isEmpty {
            Text(svc.boards.isEmpty && svc.trips.isEmpty ? (svc.failed.isEmpty ? "Lädt …" : "Fahrplan nicht erreichbar") : "Gerade keine Abfahrt")
                .foregroundColor(Theme.secondary)
        } else if space.height < 90 || space.width < 220, let x = list.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack { LineBadge(line: x.line); Text(x.top).font(.subheadline).lineLimit(1) }
                Text(leaveText(x.leave)).font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundColor(x.leave.timeIntervalSinceNow < 120 ? Theme.accent : .primary)
                Text(x.sub).font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, x in
                    if i > 0 { Divider() }
                    HStack(spacing: 10) {
                        LineBadge(line: x.line)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text("Los " + leaveText(x.leave)).font(.subheadline.weight(.semibold))
                                    .foregroundColor(x.leave.timeIntervalSinceNow < 120 ? Theme.accent : .primary)
                                Text(x.top).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
                            }
                            Text(x.sub).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if x.delay > 0 { Text("+\(x.delay)").font(.caption.weight(.semibold)).foregroundColor(.red) }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

struct TransitDetail: View {
    let routes: [TransitBucket.Route]
    @ObservedObject private var svc = TransitService.shared

    var body: some View {
        List {
            if routes.isEmpty { Text("Noch kein Startpunkt gewählt").foregroundColor(Theme.secondary) }
            ForEach(routes) { r in
                Section(header: Text(r.title + (r.from.stop && r.walk > 0 ? " · \(r.walk) min zu Fuß" : ""))) {
                    if r.to != nil { journeys(r) } else { departures(r) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshing(id: routes.map { $0.key }.joined(), every: { 60 }) { await svc.load(routes) }
    }

    @ViewBuilder private func departures(_ r: TransitBucket.Route) -> some View {
        let deps = Array((svc.boards[r.from.id] ?? []).filter { r.accepts($0) && $0.actual > Date().addingTimeInterval(-60) }.prefix(12))
        if !r.from.stop {
            Text("Ohne Ziel zeigt Hubert Abfahrten – dafür bitte eine Haltestelle als Start wählen oder ein Ziel festlegen.")
                .foregroundColor(Theme.secondary)
        } else if deps.isEmpty {
            status(r.from.id, loaded: svc.boards[r.from.id] != nil)
        }
        ForEach(deps) { d in
            HStack(spacing: 12) {
                LineBadge(line: d.line)
                Text(d.dest).lineLimit(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Fmt.hhmm(d.actual)).font(.body.monospacedDigit().weight(.semibold)).foregroundColor(d.delay > 0 ? .red : .primary)
                    Text(d.delay > 0 ? "+\(d.delay) min" : d.realtime ? "pünktlich" : "Plan")
                        .font(.caption).foregroundColor(d.delay > 0 ? .red : Theme.secondary)
                }
            }
        }
    }

    @ViewBuilder private func journeys(_ r: TransitBucket.Route) -> some View {
        let list = (svc.trips[r.key] ?? []).filter { $0.leave > Date().addingTimeInterval(-60) }
        if list.isEmpty { status(r.key, loaded: svc.trips[r.key] != nil) }
        ForEach(list) { j in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(Fmt.hhmm(j.depart) + " → " + Fmt.hhmm(j.arrive)).font(.headline.monospacedDigit())
                        .foregroundColor(j.delay > 0 ? .red : .primary)
                    Text("\(Int(j.arrive.timeIntervalSince(j.depart) / 60)) min").foregroundColor(Theme.secondary)
                    Spacer()
                    Text("Los " + leaveText(j.leave)).font(.subheadline.weight(.semibold))
                        .foregroundColor(j.leave.timeIntervalSinceNow < 120 ? Theme.accent : Theme.secondary)
                }
                HStack(spacing: 4) {
                    ForEach(Array(j.rides.enumerated()), id: \.offset) { i, ride in
                        if i > 0 { Image(systemName: "chevron.right").font(.caption2).foregroundColor(Theme.secondary) }
                        LineBadge(line: ride.line)
                    }
                    Text(j.changes == 0 ? "direkt" : "\(j.changes)× umsteigen").font(.caption).foregroundColor(Theme.secondary)
                }
                if j.changes > 0 {
                    Text(j.rides.dropFirst().map { "Umstieg " + $0.from + " " + Fmt.hhmm($0.dep) }.joined(separator: " · "))
                        .font(.caption).foregroundColor(Theme.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func status(_ key: String, loaded: Bool) -> some View {
        Text(svc.failed.contains(key) ? "Fahrplan nicht erreichbar" : loaded ? "Gerade keine Verbindung" : "Lädt …")
            .foregroundColor(Theme.secondary)
    }
}

// MARK: Einstellungen

/// Suchfeld für Haltestellen/Adressen mit Trefferliste
struct PlaceSearch: View {
    let prompt: String
    let onPick: (TransitBucket.Place) -> Void
    @State private var query = ""
    @State private var results: [TransitBucket.Place] = []
    @State private var searching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(prompt, text: $query).onSubmit { Task { await search() } }
                if searching { ProgressView() }
                else { Button("Suchen") { Task { await search() } }.buttonStyle(.borderless).disabled(query.count < 3) }
            }
            ForEach(results, id: \.self) { p in
                Button {
                    onPick(p); results = []; query = ""
                } label: {
                    Label(p.name, systemImage: p.stop ? "bus" : "house").foregroundColor(.primary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func search() async {
        searching = true
        results = await TransitService.shared.search(query, stopsOnly: false)
        searching = false
    }
}

struct TransitSettings: View {
    @Binding var config: [String: JSON]
    @State private var pickingTarget: String?    // Eintrag, für den gerade ein Ziel gesucht wird

    private var routes: [TransitBucket.Route] { TransitBucket.routes(config) }

    private func update(_ key: String, _ change: (inout TransitBucket.Route) -> Void) {
        var list = routes
        if let i = list.firstIndex(where: { $0.key == key }) { change(&list[i]) }
        TransitBucket.store(list, in: &config)
    }

    var body: some View {
        ForEach(routes) { r in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Von: " + r.from.name, systemImage: r.from.stop ? "bus" : "house").font(.headline)
                    Spacer()
                    Button(role: .destructive) {
                        var l = routes; l.removeAll { $0.key == r.key }; TransitBucket.store(l, in: &config)
                    } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                }
                if let to = r.to {
                    HStack {
                        Label("Nach: " + to.name, systemImage: "flag.checkered")
                        Spacer()
                        Button("Entfernen") { update(r.key) { $0.to = nil } }.buttonStyle(.borderless).font(.footnote)
                    }
                } else if pickingTarget == r.key {
                    PlaceSearch(prompt: "Ziel suchen, z. B. Regensburg Hbf") { p in
                        update(r.key) { $0.to = p }; pickingTarget = nil
                    }
                } else {
                    Button { pickingTarget = r.key } label: {
                        Label("Ziel festlegen (optional)", systemImage: "flag.checkered")
                    }
                    .buttonStyle(.borderless)
                }
                if r.from.stop {
                    Stepper("Fußweg zur Haltestelle: \(r.walk) min", value: Binding(
                        get: { r.walk }, set: { v in update(r.key) { $0.walk = v } }), in: 0...30)
                }
                if r.to == nil {
                    TextField("Nur Linien, z. B. 5, 11 (leer = alle)", text: Binding(
                        get: { r.lines }, set: { v in update(r.key) { $0.lines = v } }))
                }
            }
            .padding(.vertical, 4)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Startpunkt hinzufügen").font(.subheadline.weight(.semibold))
            PlaceSearch(prompt: "Haltestelle oder Adresse, z. B. Regensburg Arnulfsplatz") { p in
                var l = routes
                l.append(TransitBucket.Route(key: UUID().uuidString, from: p, to: nil, walk: p.stop ? 5 : 0, lines: ""))
                TransitBucket.store(l, in: &config)
            }
        }
    }
}
