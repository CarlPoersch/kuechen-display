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
    let platform: String
    var delay: Int { Int(actual.timeIntervalSince(planned) / 60) }
}

struct Journey: Identifiable {
    struct Ride: Hashable { let line: String; let from: String; let to: String; let dep: Date; let arr: Date }
    let id: String
    let leave: Date        // wann man losgeht (inkl. Fußweg)
    let depart: Date       // Abfahrt des ersten Fahrzeugs
    let arrive: Date
    let delay: Int         // Verspätung des ersten Fahrzeugs
    let footMinutes: Int   // Fußweg vor dem ersten Fahrzeug (bei Start an einer Adresse)
    let rides: [Ride]
    var changes: Int { max(0, rides.count - 1) }
}

/// Eine Zeile wie am Bus-Display: Linie · Ziel · Los · Ab · An
struct TransitRow: Identifiable {
    let id: String
    let line: String
    let title: String      // Fahrtziel oder "Umstieg Hbf"
    let detail: String     // z. B. "ab Otto-Hahn-Straße · Steig 2"
    let leave: Date        // Los
    let depart: Date       // Ab
    let arrive: Date?      // An (nur mit Ziel)
    let delay: Int
    let transferLine: String?
}

private struct DMResponse: Decodable {
    struct T: Decodable { let year: String; let month: String; let day: String; let hour: String; let minute: String
        var date: Date? {
            var c = DateComponents(); c.year = Int(year); c.month = Int(month); c.day = Int(day); c.hour = Int(hour); c.minute = Int(minute)
            return Calendar.current.date(from: c)
        }
    }
    struct Line: Decodable { let number: String?; let direction: String?; let key: String? }
    struct D: Decodable { let dateTime: T?; let realDateTime: T?; let servingLine: Line?; let platform: String?; let platformName: String? }
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
                                 planned: p, actual: a ?? p, realtime: a != nil,
                                 platform: (d.platformName?.isEmpty == false ? d.platformName : d.platform) ?? "")
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
                let foot = firstLeg.isRide ? 0 : Int(((firstLeg.destination.arr ?? first.dep).timeIntervalSince(firstLeg.origin.dep ?? first.dep)) / 60)
                out.append(Journey(id: id, leave: leave, depart: first.dep, arrive: arrive, delay: max(0, delay),
                                   footMinutes: foot, rides: rides))
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

    /// Zeilen eines Eintrags, nach "Los" sortiert, nur noch erreichbare
    func rows(_ r: TransitBucket.Route) -> [TransitRow] {
        let now = Date().addingTimeInterval(-30)
        if r.to != nil {
            return (trips[r.key] ?? []).filter { $0.leave > now }.map { j in
                let first = j.rides[0]
                var detail = "ab " + shortStop(first.from)
                if j.footMinutes > 0 { detail += " · \(j.footMinutes) min Fußweg" }
                var title = shortStop(first.to), transfer: String?
                if j.rides.count > 1 {
                    let next = j.rides[1]
                    title = "Umstieg " + shortStop(next.from)
                    transfer = next.line
                    let wait = Int(next.dep.timeIntervalSince(first.arr) / 60)
                    detail += " · weiter \(Fmt.hhmm(next.dep)) (\(wait) min)"
                    if j.rides.count > 2 { detail += " · +\(j.rides.count - 2) Umstieg" }
                }
                return TransitRow(id: r.key + j.id, line: first.line, title: title, detail: detail, leave: j.leave,
                                  depart: j.depart, arrive: j.arrive, delay: j.delay, transferLine: transfer)
            }
        }
        return (boards[r.from.id] ?? []).filter { r.accepts($0) }.compactMap { d in
            let leave = d.actual.addingTimeInterval(-Double(r.walk) * 60)
            guard leave > now else { return nil }
            return TransitRow(id: r.key + d.id, line: d.line, title: shortStop(d.dest),
                              detail: "ab " + shortStop(r.from.name) + (d.platform.isEmpty ? "" : " · Steig " + d.platform),
                              leave: leave, depart: d.actual, arrive: nil, delay: d.delay, transferLine: nil)
        }
    }

    func loaded(_ r: TransitBucket.Route) -> Bool { r.to != nil ? trips[r.key] != nil : boards[r.from.id] != nil }
    func failed(_ r: TransitBucket.Route) -> Bool { failed.contains(r.to != nil ? r.key : r.from.id) }
}

/// "Regensburg, Arnulfsplatz" → "Arnulfsplatz": Stadtname spart Platz
func shortStop(_ s: String) -> String {
    if let i = s.firstIndex(of: ","), s[s.index(after: i)...].trimmingCharacters(in: .whitespaces).count > 2 {
        return s[s.index(after: i)...].trimmingCharacters(in: .whitespaces)
    }
    return s.replacingOccurrences(of: "Regensburg ", with: "")
}

// MARK: Ansichten (im Stil des Bus-Displays)

/// Los-Spalte: "jetzt", "4 min" oder Uhrzeit; rot = jetzt los, gelb = fertig machen
private func los(_ leave: Date) -> (String, Color) {
    let s = leave.timeIntervalSinceNow
    if s < 60 { return ("jetzt", .red) }
    if s < 3600 {
        let m = Int(s / 60)
        return ("\(m) min", m <= 2 ? .red : m <= 5 ? Color(red: 0.72, green: 0.47, blue: 0.12) : .primary)
    }
    return (Fmt.hhmm(leave), Theme.secondary)
}

/// Linienfarben wie am Display: Stadtbusse farbig, sonst Blau
func lineColor(_ l: String) -> Color {
    switch l {
    case "3": return Color(red: 0.91, green: 0.51, blue: 0.05)
    case "5": return Color(red: 0.18, green: 0.62, blue: 0.27)
    case "6": return Color(red: 0.84, green: 0.15, blue: 0.18)
    case "C6": return Color(red: 0.56, green: 0.11, blue: 0.24)
    default: return Color(red: 0.24, green: 0.44, blue: 0.71)
    }
}

let transitNavy = Color(red: 0.11, green: 0.21, blue: 0.31)

struct LineBadge: View {
    let line: String
    var body: some View {
        Text(line).font(.subheadline.weight(.bold).monospacedDigit()).foregroundColor(.white).lineLimit(1)
            .frame(minWidth: 34).padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(lineColor(line)))
    }
}

/// Kopf eines Eintrags: Start (→ Ziel) und die Spaltennamen
struct TransitHead: View {
    let route: TransitBucket.Route
    let showArrival: Bool
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(shortStop(route.from.name) + (route.to.map { " → " + shortStop($0.name) } ?? ""))
                .font(.subheadline.weight(.bold)).foregroundColor(transitNavy).lineLimit(1)
            Spacer(minLength: 6)
            col("LOS"); col("AB"); if showArrival { col("AN") }
        }
    }
    private func col(_ t: String) -> some View {
        Text(t).font(.caption2.weight(.semibold)).foregroundColor(Theme.secondary).frame(width: 52, alignment: .trailing)
    }
}

/// Eine Abfahrt/Verbindung als Zeile
struct TransitRowView: View {
    let row: TransitRow
    let showArrival: Bool
    var best = false
    var body: some View {
        let l = los(row.leave)
        HStack(spacing: 8) {
            LineBadge(line: row.line)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(row.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    if let t = row.transferLine { LineBadge(line: t).scaleEffect(0.8) }
                }
                Text(row.detail).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
            }
            Spacer(minLength: 2)
            if row.delay > 0 { Text("+\(row.delay)").font(.caption.weight(.semibold)).foregroundColor(.red) }
            Text(l.0).font(.subheadline.weight(.bold).monospacedDigit()).foregroundColor(l.1).frame(width: 52, alignment: .trailing)
            Text(Fmt.hhmm(row.depart)).font(.subheadline.monospacedDigit()).foregroundColor(row.delay > 0 ? .red : .primary)
                .frame(width: 52, alignment: .trailing)
            if showArrival {
                Text(row.arrive.map { Fmt.hhmm($0) } ?? "–").font(.subheadline.monospacedDigit()).frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 5).padding(.horizontal, best ? 6 : 0)
        .background(RoundedRectangle(cornerRadius: 8).fill(best ? Color(red: 0.89, green: 0.92, blue: 0.95) : .clear))
    }
}

struct TransitGlance: View {
    let routes: [TransitBucket.Route]
    @ObservedObject private var svc = TransitService.shared
    @Environment(\.glanceSpace) private var space
    @Environment(\.editBucket) private var edit

    var body: some View {
        content.refreshing(id: routes.map { $0.key + ($0.to?.id ?? "") + "\($0.walk)" }.joined(), every: { 60 }) {
            await TransitService.shared.load(routes)
        }
    }

    /// Platz auf die Einträge verteilen: je Eintrag Kopf + so viele Zeilen wie passen
    private var sections: [(route: TransitBucket.Route, rows: [TransitRow])] {
        var left = space.height, out: [(route: TransitBucket.Route, rows: [TransitRow])] = []
        let per = max(1, Int((space.height - CGFloat(routes.count) * 24) / 44) / max(1, routes.count))
        for r in routes {
            guard left >= 24 + 40 else { break }
            let n = min(per, Int((left - 24) / 44), 6)
            let rows = Array(svc.rows(r).prefix(max(1, n)))
            out.append((r, rows)); left -= 24 + CGFloat(max(1, rows.count)) * 44
        }
        return out
    }

    @ViewBuilder private var content: some View {
        let wide = space.width > 420
        if routes.isEmpty {
            // Antippen öffnet die Details, dort (oder über den Regler oben) Start festlegen
            Label("Startpunkt festlegen", systemImage: "plus.circle.fill").font(.headline).foregroundColor(Theme.accent)
        } else if space.width < 260 {
            // Kleine Karte: nur die nächste Fahrt, groß
            let next = routes.flatMap { svc.rows($0) }.sorted { $0.leave < $1.leave }.first
            if let x = next {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { LineBadge(line: x.line); Text(x.title).font(.subheadline).lineLimit(1) }
                    Text(los(x.leave).0).font(.system(size: 30, weight: .bold).monospacedDigit()).foregroundColor(los(x.leave).1)
                    Text("ab " + Fmt.hhmm(x.depart) + " · " + x.detail.replacingOccurrences(of: "ab ", with: "")).font(.caption)
                        .foregroundColor(Theme.secondary).lineLimit(2)
                }
            } else {
                Text("Lädt …").foregroundColor(Theme.secondary)
            }
        } else {
            table(wide)
        }
    }

    private func table(_ wide: Bool) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sections, id: \.route.key) { sec in
                    TransitHead(route: sec.route, showArrival: wide && sec.route.to != nil)
                    if sec.rows.isEmpty {
                        Text(svc.failed(sec.route) ? "Fahrplan nicht erreichbar" : svc.loaded(sec.route) ? "Gerade keine Fahrt" : "Lädt …")
                            .font(.subheadline).foregroundColor(Theme.secondary).frame(height: 36)
                    }
                    ForEach(Array(sec.rows.enumerated()), id: \.element.id) { i, row in
                        TransitRowView(row: row, showArrival: wide && sec.route.to != nil, best: i == 0)
                    }
                }
            }
            .contentShape(Rectangle())
    }
}

struct TransitDetail: View {
    let routes: [TransitBucket.Route]
    @ObservedObject private var svc = TransitService.shared
    @Environment(\.editBucket) private var edit

    var body: some View {
        List {
            if routes.isEmpty {
                Button(action: edit) { Label("Startpunkt festlegen", systemImage: "plus.circle.fill") }
            }
            ForEach(routes) { r in
                Section(footer: footer(r)) {
                    TransitHead(route: r, showArrival: r.to != nil)
                    let rows = Array(svc.rows(r).prefix(10))
                    if rows.isEmpty {
                        Text(svc.failed(r) ? "Fahrplan nicht erreichbar" : svc.loaded(r) ? "Gerade keine Fahrt" : "Lädt …")
                            .foregroundColor(Theme.secondary)
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        TransitRowView(row: row, showArrival: r.to != nil, best: i == 0)
                    }
                }
            }
            if !routes.isEmpty {
                Section {
                    Button(action: edit) { Label("Start und Ziele bearbeiten", systemImage: "slider.horizontal.3") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshing(id: routes.map { $0.key + ($0.to?.id ?? "") }.joined(), every: { 60 }) { await svc.load(routes) }
    }

    private func footer(_ r: TransitBucket.Route) -> Text {
        if r.to == nil && !r.from.stop { return Text("Für Abfahrten eine Haltestelle als Start wählen oder ein Ziel festlegen.") }
        var parts: [String] = []
        if r.from.stop && r.walk > 0 { parts.append("\(r.walk) min Fußweg zur Haltestelle") }
        if !r.lines.isEmpty { parts.append("nur Linien " + r.lines) }
        parts.append("Los = wann du losgehen musst")
        return Text(parts.joined(separator: " · "))
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
