import SwiftUI
import Combine
import MapKit

// ============================================================
// „Wo ist der Bus?“ – eine Fahrt antippen: Karte mit allen Haltestellen
// der Linie und der ungefähren Position des Busses, darunter der Verlauf
// mit Echtzeit. Position = zwischen der letzten und der nächsten Haltestelle,
// anteilig nach den (Echtzeit-)Zeiten. Ein GPS-Signal liefert die Auskunft nicht.
// Bei Umstiegen: Anschlussfahrt in eigener Farbe darunter und auf der Karte,
// dazu die Umstiegszeit aus beiden Echtzeiten („Anschluss klappt“ / „knapp“).
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
    let refs: [RideRef]                      // [0] = erste Fahrt, danach Anschlüsse
    @Published private(set) var legs: [[RideStop]]
    @Published private(set) var failed: [Bool]
    @Published private(set) var loadedAt: Date?

    init(ref: RideRef) {
        var first = ref; first.next = []
        refs = [first] + ref.next
        legs = Array(repeating: [], count: refs.count)
        failed = Array(repeating: false, count: refs.count)
    }

    func live(_ k: Int) -> Bool { legs[k].contains { $0.live } }
    var anyLive: Bool { legs.contains { $0.contains { $0.live } } }

    /// Haltestelle, an der man in Fahrt k einsteigt
    func board(_ k: Int) -> Int? {
        let s = legs[k], r = refs[k]
        return s.firstIndex { $0.stopId == r.stop } ?? s.firstIndex { shortStop($0.name) == shortStop(r.stopName) }
    }
    /// Haltestelle, an der man aus Fahrt k aussteigt (nach dem Einstieg)
    func exit(_ k: Int) -> Int? {
        let s = legs[k], r = refs[k]
        guard r.exit != nil || r.exitName != nil else { return nil }
        let from = (board(k) ?? -1) + 1
        guard from < s.count else { return nil }
        let rest = s[from...]
        if let e = r.exit, let i = rest.firstIndex(where: { $0.stopId == e }) { return i }
        if let n = r.exitName { return rest.firstIndex { shortStop($0.name) == shortStop(n) } }
        return nil
    }
    /// Angezeigte Haltestellen: erste Fahrt bis zum Ausstieg, Anschlüsse ab dem Einstieg
    func shown(_ k: Int) -> [RideStop] {
        let s = legs[k]
        guard !s.isEmpty else { return [] }
        let lo = k == 0 ? 0 : (board(k) ?? 0)
        let hi = exit(k) ?? s.count - 1
        guard lo <= hi else { return s }
        return Array(s[lo...hi])
    }
    /// Ankunft am Ausstieg / Abfahrt am Einstieg – Echtzeit, sonst laut Verbindung
    func arrival(_ k: Int) -> Date? { exit(k).flatMap { legs[k][$0].arr ?? legs[k][$0].dep } ?? refs[k].exitTime }
    func departure(_ k: Int) -> Date? { board(k).flatMap { legs[k][$0].dep ?? legs[k][$0].arr } ?? refs[k].planned }

    func load() async {
        for k in refs.indices {
            if let list = await fetch(refs[k]) { legs[k] = list; failed[k] = false }
            else if legs[k].isEmpty { failed[k] = true }
        }
        loadedAt = Date()
    }

    private func fetch(_ ref: RideRef) async -> [RideStop]? {
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
            return list.isEmpty ? nil : list
        } catch {
            print("ÖPNV Fahrtverlauf:", error)
            return nil
        }
    }
}

/// Blatt: Fahrt verfolgen (bei Umstiegen samt Anschluss)
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
        enum Kind { case stop, past, mine, change, goal, bus }
        let id: String
        let coord: CLLocationCoordinate2D
        let kind: Kind
        let color: Color
        let line: String
    }

    private var count: Int { model.refs.count }

    /// Farbe einer Fahrt; hat der Anschluss dieselbe Linienfarbe, bekommt er Lila
    private func color(_ k: Int) -> Color {
        let r = model.refs
        if k > 0, lineColorIndex(r[k].line) == lineColorIndex(r[k - 1].line) {
            return Color(red: 0.55, green: 0.32, blue: 0.82)
        }
        return lineColor(r[k].line)
    }

    var body: some View {
        NavigationView {
            TimelineView(.periodic(from: .now, by: 5)) { ctx in
                let pos = model.legs.map { RidePosition.at($0, now: ctx.date) }
                ScrollViewReader { reader in
                    List {
                        Section { mapView(pos).listRowInsets(EdgeInsets()) }
                        Section { status(pos[0], now: ctx.date) }
                        // Umstieg(e): reicht die Zeit für den Anschluss?
                        ForEach(Array(model.refs.indices.dropFirst()), id: \.self) { k in
                            Section(header: Text(count > 2 ? "\(k). Umstieg" : "Umstieg")) { transferCard(k, pos: pos) }
                        }
                        ForEach(Array(model.refs.indices), id: \.self) { k in
                            Section(header: legHeader(k), footer: legFooter(k)) { legRows(k, pos: pos[k]) }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .onChange(of: model.loadedAt) { _ in
                        // Beim ersten Laden zum Bus springen
                        if !fitted, let i = busIndex(pos[0]) { reader.scrollTo("0-\(max(0, i - 1))", anchor: .top) }
                        fit(pos)
                    }
                }
            }
            .navigationTitle(model.refs.map { "Linie " + $0.line }.joined(separator: " → "))
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

    private func pins(_ pos: [RidePosition]) -> [Pin] {
        var out: [Pin] = []
        for k in model.refs.indices {
            let c = color(k), line = model.refs[k].line, last = k == count - 1
            let passed = passedIndex(k, pos[k]), b = model.board(k), e = model.exit(k)
            for s in model.shown(k) {
                guard let xy = s.coord else { continue }
                var kind: Pin.Kind = s.id <= passed ? .past : .stop
                if k == 0 && s.id == b { kind = .mine }
                else if s.id == e { kind = last ? .goal : .change }
                else if k > 0 && s.id == b { kind = .change }
                out.append(Pin(id: "\(k)-\(s.id)", coord: xy, kind: kind, color: c, line: line))
            }
            // Bus zeigen, solange er für uns zählt (nicht schon hinter dem Ausstieg)
            let gone = e.map { passed >= $0 } ?? false
            if pos[k].phase != .done, !gone, let xy = pos[k].coord {
                out.append(Pin(id: "bus\(k)", coord: xy, kind: .bus, color: c, line: line))
            }
        }
        return out
    }

    private func mapView(_ pos: [RidePosition]) -> some View {
        Map(coordinateRegion: $region, annotationItems: pins(pos)) { p in
            MapAnnotation(coordinate: p.coord) {
                switch p.kind {
                case .bus:
                    HStack(spacing: 3) {
                        Image(systemName: "bus.fill").font(.system(size: 12, weight: .bold))
                        if count > 1 { Text(p.line).font(.system(size: 12, weight: .bold).monospacedDigit()) }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, count > 1 ? 8 : 0)
                    .frame(minWidth: 30, minHeight: 30)
                    .background(Capsule().fill(p.color))
                    .overlay(Capsule().stroke(Color.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                case .mine:
                    Circle().fill(Theme.accent).frame(width: 14, height: 14).overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                case .change:
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 9, weight: .bold)).foregroundColor(Theme.accent)
                        .frame(width: 22, height: 22).background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(Theme.accent, lineWidth: 2.5))
                case .goal:
                    Image(systemName: "flag.checkered").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .frame(width: 22, height: 22).background(Circle().fill(transitNavy))
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                case .stop:
                    Circle().fill(Color.white).frame(width: 9, height: 9).overlay(Circle().stroke(p.color, lineWidth: 2.5))
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

    /// Ausschnitt: Busse, eigener Einstieg und Umstiege – sonst die ganze Strecke
    private func fit(_ pos: [RidePosition], force: Bool = false) {
        guard force || !fitted else { return }
        var pts: [CLLocationCoordinate2D] = []
        for k in model.refs.indices {
            if pos[k].phase != .done, let c = pos[k].coord { pts.append(c) }
            if k == 0, let b = model.board(0), let c = model.legs[0][b].coord { pts.append(c) }
            if k < count - 1, let e = model.exit(k), let c = model.legs[k][e].coord { pts.append(c) }
        }
        if pts.count < 2 { pts = model.refs.indices.flatMap { model.shown($0) }.compactMap { $0.coord } }
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

    /// „Zwischen A und B“ usw. für Fahrt k
    private func describe(_ k: Int, _ pos: RidePosition) -> String {
        let s = model.legs[k]
        switch pos.phase {
        case .before:
            if let f = s.first { return "Startet " + Fmt.hhmm(f.time ?? Date()) + " an " + shortStop(f.name) }
            return "Richtung " + shortStop(model.refs[k].toward)
        case .at(let i): return "Steht an " + shortStop(s[i].name)
        case .between(let i, _): return "Zwischen " + shortStop(s[i].name) + " und " + shortStop(s[i + 1].name)
        case .done: return "Fahrt beendet"
        }
    }

    private func status(_ pos: RidePosition, now: Date) -> some View {
        let s = model.legs[0]
        var sub = ""
        if let m = model.board(0), let t = s[m].arr ?? s[m].dep {
            let mins = Int((t.timeIntervalSince(now) / 60).rounded())
            if passedIndex(0, pos) >= m { sub = "Schon an " + shortStop(s[m].name) + " vorbei" }
            else { sub = mins <= 0 ? "Jetzt an " + shortStop(s[m].name) : "In \(mins) min an " + shortStop(s[m].name) + " (" + Fmt.hhmm(t) + ")" }
        }
        let live = model.live(0)
        let title = s.isEmpty ? "Richtung " + shortStop(model.refs[0].toward) : describe(0, pos)
        let delay = model.board(0).map { s[$0].delay } ?? s.first(where: { $0.live })?.delay ?? 0
        return HStack(spacing: 12) {
            LineBadge(line: model.refs[0].line)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).lineLimit(2)
                if !sub.isEmpty { Text(sub).font(.subheadline).foregroundColor(Theme.secondary) }
                HStack(spacing: 6) {
                    Circle().fill(live ? Color.green : Color.gray).frame(width: 7, height: 7)
                    Text(live ? (delay > 0 ? "Live · \(delay) min später" : "Live · pünktlich") : "Fahrplan")
                        .font(.caption.weight(.semibold)).foregroundColor(live && delay > 0 ? .red : Theme.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    /// Umstieg k-1 → k: Ankunft, Abfahrt des Anschlusses, Puffer abzüglich Fußweg
    private func transferCard(_ k: Int, pos: [RidePosition]) -> some View {
        let r = model.refs[k], prev = model.refs[k - 1]
        let arr = model.arrival(k - 1), dep = model.departure(k)
        var wait: Int?
        if let a = arr, let d = dep { wait = Int((d.timeIntervalSince(a) / 60).rounded()) }
        let slack = wait.map { $0 - r.walkBefore }
        let live = model.live(k - 1) || model.live(k)
        var verdict = "Umstiegszeit wird berechnet", tint = Theme.secondary, ok = true
        if let s = slack {
            if s >= 2 { verdict = "Anschluss klappt" }
            else if s >= 0 { verdict = "Knapp – zügig umsteigen"; tint = .orange; ok = false }
            else { verdict = "Anschluss gefährdet"; tint = .red; ok = false }
            verdict += live ? " · live" : " · laut Fahrplan"
        }
        var times = ""
        if let a = arr { times += "An " + Fmt.hhmm(a) }
        if let d = dep { times += (times.isEmpty ? "" : " · ") + "weiter " + Fmt.hhmm(d) }
        if let w = wait { times += " · \(max(0, w)) min" + (r.walkBefore > 0 ? " (davon \(r.walkBefore) min Fußweg)" : "") }
        return HStack(alignment: .top, spacing: 12) {
            LineBadge(line: r.line, color: color(k))
            VStack(alignment: .leading, spacing: 3) {
                Text("Umsteigen an " + shortStop(prev.exitName ?? r.stopName)).font(.headline).lineLimit(2)
                if !times.isEmpty { Text(times).font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary) }
                if !model.legs[k].isEmpty {
                    Text("Bus \(r.line): " + describe(k, pos[k])).font(.caption).foregroundColor(Theme.secondary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    Circle().fill(slack == nil ? Color.gray : ok ? Color.green : tint).frame(width: 7, height: 7)
                    Text(verdict).font(.caption.weight(.semibold)).foregroundColor(tint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: Verlauf

    private func legHeader(_ k: Int) -> Text {
        guard count > 1 else { return Text("Verlauf") }
        let r = model.refs[k]
        let to = r.exitName.map { " · bis " + shortStop($0) } ?? ""
        return Text((k == 0 ? "Linie " : "Anschluss Linie ") + r.line + to)
    }

    @ViewBuilder private func legFooter(_ k: Int) -> some View {
        if k == count - 1 && model.legs.contains(where: { !$0.isEmpty }) {
            Text(model.anyLive ? "Zeiten mit Echtzeit. Die Position ist aus den Zeiten geschätzt, nicht per GPS."
                               : "Für diese Fahrt gibt es gerade keine Echtzeit – Position nach Fahrplan.")
        }
    }

    @ViewBuilder private func legRows(_ k: Int, pos: RidePosition) -> some View {
        let stops = model.shown(k)
        if stops.isEmpty {
            if model.failed[k] { Text("Verlauf dieser Fahrt gerade nicht verfügbar").foregroundColor(Theme.secondary) }
            else { HStack(spacing: 10) { ProgressView(); Text("Lädt Verlauf …").foregroundColor(Theme.secondary) } }
        } else {
            if k > 0, let text = approach(k, pos) {
                HStack(spacing: 12) {
                    Image(systemName: "bus.fill").font(.caption.weight(.bold)).foregroundColor(.white)
                        .frame(width: 22, height: 22).background(Circle().fill(color(k)))
                    Text(text).font(.caption.weight(.semibold)).foregroundColor(color(k))
                }
            }
            ForEach(stops) { s in stopRow(k, s, pos: pos).id("\(k)-\(s.id)") }
        }
    }

    /// Anschlussbus noch vor dem Einstieg: wie weit ist er weg?
    private func approach(_ k: Int, _ pos: RidePosition) -> String? {
        guard let b = model.board(k) else { return nil }
        let line = model.refs[k].line
        switch pos.phase {
        case .before: return "Bus \(line): " + describe(k, pos)
        case .at(let i), .between(let i, _):
            guard i < b else { return nil }
            let n = b - i
            return n == 1 ? "Bus \(line) ist eine Haltestelle vorher" : "Bus \(line) ist noch \(n) Haltestellen entfernt"
        case .done: return nil
        }
    }

    /// Index der letzten Haltestelle, an der der Bus schon war
    private func passedIndex(_ k: Int, _ pos: RidePosition) -> Int {
        switch pos.phase {
        case .before: return -1
        case .at(let i): return i - 1
        case .between(let i, _): return i
        case .done: return model.legs[k].count
        }
    }
    private func busIndex(_ pos: RidePosition) -> Int? {
        switch pos.phase { case .at(let i), .between(let i, _): return i; default: return nil }
    }

    private func stopRow(_ k: Int, _ s: RideStop, pos: RidePosition) -> some View {
        let c = color(k)
        let passed = s.id <= passedIndex(k, pos)
        let here: Bool = { if case .at(let i) = pos.phase { return i == s.id }; return false }()
        let after: Bool = { if case .between(let i, _) = pos.phase { return i == s.id }; return false }()
        let isBoard = s.id == model.board(k), isExit = s.id == model.exit(k)
        var label: String?
        if k == 0 && isBoard { label = "Dein Einstieg" }
        else if isExit { label = k < count - 1 ? "Umsteigen in Linie " + model.refs[k + 1].line : "Ausstieg" }
        else if k > 0 && isBoard { label = "Hier einsteigen" }
        let strong = label != nil
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Circle().fill(here ? c : passed ? Color.gray.opacity(0.5) : Color(UIColor.systemBackground))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(passed ? Color.clear : c, lineWidth: 2.5))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(shortStop(s.name)).font(strong ? .body.weight(.semibold) : .body)
                        .foregroundColor(passed ? Theme.secondary : .primary).lineLimit(1)
                    if let l = label { Text(l).font(.caption.weight(.semibold)).foregroundColor(Theme.accent) }
                    if here { Text("Bus ist hier").font(.caption.weight(.semibold)).foregroundColor(c) }
                }
                Spacer(minLength: 4)
                if let t = s.time {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Fmt.hhmm(t)).font(.subheadline.monospacedDigit().weight(strong ? .semibold : .regular))
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
                        .frame(width: 22, height: 22).background(Circle().fill(c))
                    Text("Bus ist unterwegs zur nächsten Haltestelle").font(.caption.weight(.semibold)).foregroundColor(c)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
