import SwiftUI
import Combine

// ============================================================
// ÖPNV-Bucket. Du legst Orte an (Haltestellen oder Adressen) und gibst
// ihnen Namen wie "Zuhause", "Uni", "Philipp". In der Karte wählst du
// per Menü "Von" und "Nach":
//  - Nach = "Abfahrten": Abfahrtstafel der Start-Haltestelle
//  - Nach = ein Ort:     Verbindungen dorthin (mit Umstiegen)
// "Los" = wann man aus der Tür muss (Abfahrt minus Fußweg).
// Quelle: Bayern-Fahrplanauskunft (EFA) über die Supabase-Funktion "efa".
// Einstellungen: places = [{ key, label, id, name, stop, walk, lines }], from = key, to = key | ""
// ============================================================
enum TransitBucket {
    static let kind = BucketKind(
        id: "oepnv", name: "ÖPNV", symbol: "bus.fill", tint: .blue, art: .glance,
        interests: ["unterwegs"], blurb: "Wann du los musst – Abfahrten oder Verbindungen zu deinen Orten (Bayern).",
        needsSetup: { saved($0).isEmpty },
        glance: { inst, size in AnyView(TransitGlance(config: inst.config)) },
        detail: { inst in AnyView(TransitDetail(config: inst.config)) },
        itemLinks: true,   // Menüs in der Karte; Details über "Alle ›"
        settings: { binding in AnyView(TransitSettings(config: binding)) }
    )

    /// Ein Ort laut Fahrplanauskunft
    struct Place: Equatable, Hashable {
        var id: String      // Haltestellen-Nummer oder EFA-Ortskennung (Adresse)
        var name: String
        var stop: Bool
        init(id: String, name: String, stop: Bool) { self.id = id; self.name = name; self.stop = stop }
        init?(_ j: JSON?) {
            guard let o = j?.object, let id = o["id"]?.string, let n = o["name"]?.string else { return nil }
            self.init(id: id, name: n, stop: o["stop"]?.bool ?? true)
        }
    }

    /// Ein gespeicherter Ort mit eigenem Namen
    struct Saved: Identifiable, Equatable {
        var key: String
        var label: String
        var loc: Place
        var walk: Int        // Fußweg zur Haltestelle (nur bei Haltestellen)
        var lines: String    // Linienfilter für die Abfahrtstafel
        var id: String { key }
        var json: JSON {
            .object(["key": .string(key), "label": .string(label), "id": .string(loc.id), "name": .string(loc.name),
                     "stop": .bool(loc.stop), "walk": .number(Double(walk)), "lines": .string(lines)])
        }
    }

    struct Route: Identifiable, Equatable {
        var key: String
        var from: Place
        var to: Place?
        var walk: Int
        var lines: String
        var id: String { key }

        func accepts(_ d: Departure) -> Bool {
            let wanted = lines.split(whereSeparator: { $0 == "," || $0 == " " }).map { String($0).lowercased() }
            return wanted.isEmpty || wanted.contains(d.line.lowercased())
        }
    }

    static func saved(_ c: [String: JSON]) -> [Saved] {
        if let list = c["places"]?.array {
            return list.compactMap { j in
                guard let o = j.object, let key = o["key"]?.string, let loc = Place(j) else { return nil }
                return Saved(key: key, label: o["label"]?.string ?? shortStop(loc.name), loc: loc,
                             walk: Int(o["walk"]?.double ?? 0), lines: o["lines"]?.string ?? "")
            }
        }
        // Älteres Format (stops = Einträge mit from/to) übernehmen
        var out: [Saved] = []
        for j in c["stops"]?.array ?? [] {
            guard let o = j.object else { continue }
            let walk = Int(o["walk"]?.double ?? 0), lines = o["lines"]?.string ?? ""
            let from = Place(o["from"]) ?? o["id"]?.string.flatMap { id in o["name"]?.string.map { Place(id: id, name: $0, stop: true) } }
            for (p, isFrom) in [(from, true), (Place(o["to"]), false)] {
                guard let p = p, !out.contains(where: { $0.loc.id == p.id }) else { continue }
                out.append(Saved(key: p.id, label: shortStop(p.name), loc: p, walk: isFrom ? walk : 5, lines: isFrom ? lines : ""))
            }
        }
        return out
    }

    static func store(_ list: [Saved], in c: inout [String: JSON]) {
        c["places"] = .array(list.map { $0.json })
        c["stops"] = nil
    }

    /// Aktuelle Auswahl "Von" und "Nach" (nil = Abfahrten)
    static func selection(_ c: [String: JSON]) -> (from: Saved?, to: Saved?) {
        let list = saved(c)
        let from = list.first { $0.key == c["from"]?.string } ?? list.first
        var to = list.first { $0.key == c["to"]?.string && $0.key != from?.key }
        if c["to"] == nil, c["places"] == nil {   // altes Format: erstes Ziel übernehmen
            let old = (c["stops"]?.array ?? []).first?.object
            to = list.first { $0.loc.id == TransitBucket.Place(old?["to"])?.id && $0.key != from?.key }
        }
        // Von einer Adresse gibt es keine Abfahrtstafel → erstes anderes Ziel
        if to == nil, let f = from, !f.loc.stop { to = list.first { $0.key != f.key } }
        return (from, to)
    }

    static func route(_ from: Saved, _ to: Saved?) -> Route {
        Route(key: from.key + ">" + (to?.key ?? ""), from: from.loc, to: to?.loc, walk: from.walk, lines: from.lines)
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

/// Spaltenköpfe wie am Display, links optional ein Titel
struct TransitHead: View {
    var title: String = ""
    let showArrival: Bool
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(title).font(.subheadline.weight(.bold)).foregroundColor(.primary).lineLimit(1)
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
        .background(RoundedRectangle(cornerRadius: 8).fill(best ? Color.blue.opacity(0.13) : .clear))
    }
}

/// "Von ▾ → Nach ▾" – Auswahl direkt in der Karte, wird sofort gespeichert
struct TransitPicker: View {
    let config: [String: JSON]
    @EnvironmentObject var store: AppStore
    @Environment(\.bucketId) private var bucketId
    @Environment(\.editBucket) private var edit

    var body: some View {
        let list = TransitBucket.saved(config)
        let sel = TransitBucket.selection(config)
        HStack(spacing: 6) {
            Menu {
                ForEach(list) { p in
                    Button { set("from", p.key) } label: { item(p, on: p.key == sel.from?.key) }
                }
                Divider()
                Button(action: edit) { Label("Orte bearbeiten …", systemImage: "slider.horizontal.3") }
            } label: { chip(sel.from?.label ?? "Start", icon: sel.from?.loc.stop == false ? "house.fill" : "bus") }
            Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundColor(Theme.secondary)
            Menu {
                if sel.from?.loc.stop == true {
                    Button { set("to", "") } label: {
                        if sel.to == nil { Label("Abfahrten", systemImage: "checkmark") } else { Text("Abfahrten") }
                    }
                }
                ForEach(list.filter { $0.key != sel.from?.key }) { p in
                    Button { set("to", p.key) } label: { item(p, on: p.key == sel.to?.key) }
                }
                Divider()
                Button(action: edit) { Label("Ort hinzufügen …", systemImage: "plus") }
            } label: { chip(sel.to?.label ?? "Abfahrten", icon: sel.to == nil ? "list.bullet" : "flag.checkered") }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func item(_ p: TransitBucket.Saved, on: Bool) -> some View {
        if on { Label(p.label, systemImage: "checkmark") } else { Text(p.label) }
    }

    private func chip(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption.weight(.semibold))
            Text(text).font(.subheadline.weight(.semibold)).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
        }
        .foregroundColor(Theme.accent)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
    }

    private func set(_ key: String, _ value: String) {
        store.updateConfig(bucketId) { c in
            c[key] = .string(value)
            if c["places"] == nil { TransitBucket.store(TransitBucket.saved(c), in: &c) }   // altes Format umstellen
        }
    }
}

struct TransitGlance: View {
    let config: [String: JSON]
    @ObservedObject private var svc = TransitService.shared
    @Environment(\.glanceSpace) private var space

    private var route: TransitBucket.Route? {
        let sel = TransitBucket.selection(config)
        return sel.from.map { TransitBucket.route($0, sel.to) }
    }

    var body: some View {
        content.refreshing(id: route?.key ?? "", every: { 60 }) {
            if let r = route { await TransitService.shared.load([r]) }
        }
    }

    @ViewBuilder private var content: some View {
        if let r = route {
            let wide = space.width > 420
            let n = fitRows(space.height - 60, row: 44, max: 8)
            let rows = Array(svc.rows(r).prefix(n))
            VStack(alignment: .leading, spacing: 4) {
                TransitPicker(config: config)
                if space.width < 260, let x = rows.first {
                    // Kleine Karte: nur die nächste Fahrt, groß
                    HStack { LineBadge(line: x.line); Text(x.title).font(.subheadline).lineLimit(1) }.padding(.top, 4)
                    Text(los(x.leave).0).font(.system(size: 28, weight: .bold).monospacedDigit()).foregroundColor(los(x.leave).1)
                    Text("ab " + Fmt.hhmm(x.depart) + " · " + x.detail.replacingOccurrences(of: "ab ", with: ""))
                        .font(.caption).foregroundColor(Theme.secondary).lineLimit(2)
                } else {
                    TransitHead(showArrival: wide && r.to != nil).padding(.top, 2)
                    if rows.isEmpty {
                        Text(svc.failed(r) ? "Fahrplan nicht erreichbar" : svc.loaded(r) ? "Gerade keine Fahrt" : "Lädt …")
                            .font(.subheadline).foregroundColor(Theme.secondary).frame(height: 36)
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        TransitRowView(row: row, showArrival: wide && r.to != nil, best: i == 0)
                    }
                }
            }
        } else {
            Label("Orte über den Regler oben anlegen", systemImage: "plus.circle.fill")
                .font(.headline).foregroundColor(Theme.accent)
        }
    }
}

struct TransitDetail: View {
    let config: [String: JSON]
    @ObservedObject private var svc = TransitService.shared
    @Environment(\.editBucket) private var edit

    private var sel: (from: TransitBucket.Saved?, to: TransitBucket.Saved?) { TransitBucket.selection(config) }
    private var main: TransitBucket.Route? { sel.from.map { TransitBucket.route($0, sel.to) } }
    /// Zusätzlich: die anderen Orte als Ziel (mehr Überblick)
    private var others: [(TransitBucket.Saved, TransitBucket.Route)] {
        guard let f = sel.from else { return [] }
        return TransitBucket.saved(config).filter { $0.key != f.key && $0.key != sel.to?.key }.map { ($0, TransitBucket.route(f, $0)) }
    }

    var body: some View {
        List {
            Section { TransitPicker(config: config).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            if let r = main {
                Section(footer: footer(r)) {
                    TransitHead(title: sel.to.map { "Nach " + $0.label } ?? "Abfahrten", showArrival: r.to != nil)
                    rows(r, max: 10)
                }
                ForEach(others, id: \.0.key) { p, r in
                    Section {
                        TransitHead(title: "Nach " + p.label, showArrival: true)
                        rows(r, max: 3)
                    }
                }
            } else {
                Button(action: edit) { Label("Orte anlegen", systemImage: "plus.circle.fill") }
            }
            Section {
                Button(action: edit) { Label("Orte bearbeiten", systemImage: "slider.horizontal.3") }
            }
        }
        .listStyle(.insetGrouped)
        .refreshing(id: (main?.key ?? "") + others.map { $0.1.key }.joined(), every: { 60 }) {
            await svc.load([main].compactMap { $0 } + others.map { $0.1 })
        }
    }

    @ViewBuilder private func rows(_ r: TransitBucket.Route, max: Int) -> some View {
        let list = Array(svc.rows(r).prefix(max))
        if list.isEmpty {
            Text(svc.failed(r) ? "Fahrplan nicht erreichbar" : svc.loaded(r) ? "Gerade keine Fahrt" : "Lädt …")
                .foregroundColor(Theme.secondary)
        }
        ForEach(Array(list.enumerated()), id: \.element.id) { i, row in
            TransitRowView(row: row, showArrival: r.to != nil, best: i == 0)
        }
    }

    private func footer(_ r: TransitBucket.Route) -> Text {
        var parts: [String] = []
        if r.from.stop && r.walk > 0 { parts.append("\(r.walk) min Fußweg zur Haltestelle") }
        if r.to == nil && !r.lines.isEmpty { parts.append("nur Linien " + r.lines) }
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

    private var places: [TransitBucket.Saved] { TransitBucket.saved(config) }

    private func update(_ key: String, _ change: (inout TransitBucket.Saved) -> Void) {
        var list = places
        if let i = list.firstIndex(where: { $0.key == key }) { change(&list[i]) }
        TransitBucket.store(list, in: &config)
    }

    var body: some View {
        ForEach(places) { p in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: p.loc.stop ? "bus" : "house.fill").foregroundColor(Theme.accent).frame(width: 22)
                    TextField("Name, z. B. Zuhause", text: Binding(get: { p.label }, set: { v in update(p.key) { $0.label = v } }))
                        .font(.headline)
                    Button(role: .destructive) {
                        var l = places; l.removeAll { $0.key == p.key }; TransitBucket.store(l, in: &config)
                    } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                }
                Text(p.loc.name).font(.footnote).foregroundColor(Theme.secondary).padding(.leading, 30)
                if p.loc.stop {
                    Stepper("Fußweg dorthin: \(p.walk) min", value: Binding(
                        get: { p.walk }, set: { v in update(p.key) { $0.walk = v } }), in: 0...30)
                        .padding(.leading, 30)
                    TextField("Abfahrten nur für Linien, z. B. 5, 11", text: Binding(
                        get: { p.lines }, set: { v in update(p.key) { $0.lines = v } }))
                        .font(.subheadline).padding(.leading, 30)
                }
            }
            .padding(.vertical, 4)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Ort hinzufügen").font(.subheadline.weight(.semibold))
            Text("Haltestelle oder Adresse – den Namen (z. B. „Uni“) kannst du danach ändern.")
                .font(.footnote).foregroundColor(Theme.secondary)
            PlaceSearch(prompt: "z. B. Regensburg Liebermannweg 1") { loc in
                var l = places
                l.append(TransitBucket.Saved(key: UUID().uuidString, label: shortStop(loc.name), loc: loc,
                                             walk: loc.stop ? 5 : 0, lines: ""))
                TransitBucket.store(l, in: &config)
            }
        }
    }
}
