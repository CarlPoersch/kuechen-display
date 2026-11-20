import SwiftUI
import Combine

// ============================================================
// ÖPNV-Bucket: nächste Abfahrten an frei wählbaren Haltestellen.
// Quelle: Bayern-Fahrplanauskunft (EFA) über die Supabase-Funktion "efa".
// Einstellungen: stops = [{ id, name, walk (min), lines ("5, 11"), dir ("Hbf") }]
// "Los in" = Abfahrt minus Fußweg → wann man aus der Tür muss.
// ============================================================
enum TransitBucket {
    static let kind = BucketKind(
        id: "oepnv", name: "ÖPNV", symbol: "bus.fill", tint: .blue, art: .glance,
        interests: ["unterwegs"], blurb: "Wann du los musst, an deinen Haltestellen (Bayern).",
        needsSetup: { stops($0).isEmpty },
        glance: { inst, size in AnyView(TransitGlance(stops: stops(inst.config), size: size)) },
        detail: { inst in AnyView(TransitDetail(stops: stops(inst.config))) },
        settings: { binding in AnyView(TransitSettings(config: binding)) }
    )

    struct Stop: Identifiable, Equatable {
        var id: String
        var name: String
        var walk: Int
        var lines: String
        var dir: String

        /// Passt eine Abfahrt zu den Filtern dieser Haltestelle?
        func accepts(_ d: Departure) -> Bool {
            let wanted = lines.split(whereSeparator: { $0 == "," || $0 == " " }).map { String($0).lowercased() }
            if !wanted.isEmpty && !wanted.contains(d.line.lowercased()) { return false }
            let words = dir.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
            if !words.isEmpty && !words.contains(where: { d.dest.lowercased().contains($0) }) { return false }
            return true
        }
    }

    static func stops(_ c: [String: JSON]) -> [Stop] {
        (c["stops"]?.array ?? []).compactMap { j in
            guard let o = j.object, let id = o["id"]?.string, let n = o["name"]?.string else { return nil }
            return Stop(id: id, name: n, walk: Int(o["walk"]?.double ?? 0), lines: o["lines"]?.string ?? "", dir: o["dir"]?.string ?? "")
        }
    }

    static func store(_ list: [Stop], in c: inout [String: JSON]) {
        c["stops"] = .array(list.map { s in
            .object(["id": .string(s.id), "name": .string(s.name), "walk": .number(Double(s.walk)),
                     "lines": .string(s.lines), "dir": .string(s.dir)])
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
    let stopId: String
    var delay: Int { Int(actual.timeIntervalSince(planned) / 60) }
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

private struct StopFinder: Decodable {
    struct Loc: Decodable {
        struct P: Decodable { let stopId: String? }
        let name: String?; let disassembledName: String?; let type: String?; let properties: P?
        let parent: Parent?
        struct Parent: Decodable { let name: String? }
    }
    let locations: [Loc]?
}

final class TransitService: ObservableObject {
    static let shared = TransitService()
    @Published private(set) var boards: [String: [Departure]] = [:]   // je Haltestelle
    @Published private(set) var failed: Set<String> = []
    private var loadedAt: [String: Date] = [:]

    func load(_ stopIds: [String]) async {
        await withTaskGroup(of: Void.self) { g in
            for id in Set(stopIds) { g.addTask { await self.loadOne(id) } }
        }
    }

    private func loadOne(_ id: String) async {
        if let t = loadedAt[id], Date().timeIntervalSince(t) < 45 { return }
        do {
            let data = try await SupabaseClient.shared.raw("GET", "/functions/v1/efa/XML_DM_REQUEST", query: [
                .init(name: "outputFormat", value: "JSON"), .init(name: "mode", value: "direct"),
                .init(name: "type_dm", value: "stop"), .init(name: "name_dm", value: id),
                .init(name: "useRealtime", value: "1"), .init(name: "limit", value: "40"),
            ])
            let r = try JSONDecoder().decode(DMResponse.self, from: data)
            boards[id] = (r.departureList ?? []).compactMap { d in
                guard let p = d.dateTime?.date else { return nil }
                let a = d.realDateTime?.date
                return Departure(id: id + (d.servingLine?.key ?? "") + "\(p.timeIntervalSince1970)",
                                 line: d.servingLine?.number ?? "?", dest: d.servingLine?.direction ?? "",
                                 planned: p, actual: a ?? p, realtime: a != nil, stopId: id)
            }.sorted { $0.actual < $1.actual }
            loadedAt[id] = Date()
            failed.remove(id)
        } catch {
            failed.insert(id)
            print("ÖPNV:", error)
        }
    }

    /// Haltestellen-Suche (nur Haltestellen, keine Adressen)
    func search(_ text: String) async -> [TransitBucket.Stop] {
        guard let data = try? await SupabaseClient.shared.raw("GET", "/functions/v1/efa/XML_STOPFINDER_REQUEST", query: [
            .init(name: "outputFormat", value: "rapidJSON"), .init(name: "type_sf", value: "any"),
            .init(name: "name_sf", value: text), .init(name: "anyObjFilter_sf", value: "2"),
        ]), let r = try? JSONDecoder().decode(StopFinder.self, from: data) else { return [] }
        return (r.locations ?? []).compactMap { l in
            guard let id = l.properties?.stopId, let n = l.name else { return nil }
            return TransitBucket.Stop(id: id, name: n, walk: 5, lines: "", dir: "")
        }
    }
}

/// Abfahrten aller Haltestellen, gefiltert, nach "Los in" sortiert
private func upcoming(_ stops: [TransitBucket.Stop], _ boards: [String: [Departure]]) -> [(stop: TransitBucket.Stop, dep: Departure, leave: Date)] {
    let now = Date()
    return stops.flatMap { s in
        (boards[s.id] ?? []).filter { s.accepts($0) }.map { (stop: s, dep: $0, leave: $0.actual.addingTimeInterval(-Double(s.walk) * 60)) }
    }
    .filter { $0.leave > now.addingTimeInterval(-30) }
    .sorted { $0.leave < $1.leave }
}

private func leaveText(_ leave: Date) -> String {
    let m = Int(leave.timeIntervalSinceNow / 60)
    return m <= 0 ? "jetzt los" : "in \(m) min"
}

// MARK: Ansichten

struct LineBadge: View {
    let line: String
    var body: some View {
        Text(line).font(.subheadline.weight(.bold).monospacedDigit()).foregroundColor(.white)
            .frame(minWidth: 34).padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.blue))
    }
}

struct TransitGlance: View {
    let stops: [TransitBucket.Stop]
    let size: BucketSize
    @ObservedObject private var svc = TransitService.shared

    var body: some View {
        content.refreshing(every: { 60 }) { await TransitService.shared.load(stops.map { $0.id }) }
    }

    @ViewBuilder private var content: some View {
        let list = Array(upcoming(stops, svc.boards).prefix(size == .s ? 1 : size == .m ? 3 : 6))
        if stops.isEmpty {
            Text("Haltestelle in den Einstellungen wählen").foregroundColor(Theme.secondary)
        } else if list.isEmpty {
            Text(svc.boards.isEmpty ? (svc.failed.isEmpty ? "Lädt …" : "Fahrplan nicht erreichbar") : "Gerade keine Abfahrt")
                .foregroundColor(Theme.secondary)
        } else if size == .s, let x = list.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack { LineBadge(line: x.dep.line); Text(x.dep.dest).font(.subheadline).lineLimit(1) }
                Text(leaveText(x.leave)).font(.system(size: 30, weight: .semibold).monospacedDigit())
                    .foregroundColor(x.leave.timeIntervalSinceNow < 120 ? Theme.accent : .primary)
                Text(Fmt.hhmm(x.dep.actual) + " ab " + x.stop.name).font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(list, id: \.dep.id) { x in
                    HStack(spacing: 10) {
                        LineBadge(line: x.dep.line)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Los " + leaveText(x.leave)).font(.subheadline.weight(.semibold))
                                .foregroundColor(x.leave.timeIntervalSinceNow < 120 ? Theme.accent : .primary)
                            Text(Fmt.hhmm(x.dep.actual) + " ab " + x.stop.name).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if x.dep.delay > 0 { Text("+\(x.dep.delay)").font(.caption.weight(.semibold)).foregroundColor(.red) }
                    }
                }
            }
        }
    }
}

struct TransitDetail: View {
    let stops: [TransitBucket.Stop]
    @ObservedObject private var svc = TransitService.shared

    var body: some View {
        List {
            if stops.isEmpty { Text("Noch keine Haltestelle gewählt").foregroundColor(Theme.secondary) }
            ForEach(stops) { s in
                Section(header: Text(s.name + " · \(s.walk) min zu Fuß")) {
                    let deps = (svc.boards[s.id] ?? []).filter { s.accepts($0) && $0.actual > Date().addingTimeInterval(-60) }.prefix(12)
                    if deps.isEmpty {
                        Text(svc.failed.contains(s.id) ? "Fahrplan nicht erreichbar" : svc.boards[s.id] == nil ? "Lädt …" : "Gerade keine Abfahrt")
                            .foregroundColor(Theme.secondary)
                    }
                    ForEach(Array(deps)) { d in
                        HStack(spacing: 12) {
                            LineBadge(line: d.line)
                            Text(d.dest).lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(Fmt.hhmm(d.actual)).font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundColor(d.delay > 0 ? .red : .primary)
                                Text(d.delay > 0 ? "+\(d.delay) min" : d.realtime ? "pünktlich" : "Plan")
                                    .font(.caption).foregroundColor(d.delay > 0 ? .red : Theme.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshing(every: { 60 }) { await svc.load(stops.map { $0.id }) }
    }
}

// MARK: Einstellungen

struct TransitSettings: View {
    @Binding var config: [String: JSON]
    @State private var query = ""
    @State private var results: [TransitBucket.Stop] = []
    @State private var searching = false

    private var stops: [TransitBucket.Stop] { TransitBucket.stops(config) }

    private func update(_ change: (inout [TransitBucket.Stop]) -> Void) {
        var list = stops; change(&list); TransitBucket.store(list, in: &config)
    }

    var body: some View {
        ForEach(stops) { s in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill").foregroundColor(.blue)
                    Text(s.name).font(.headline)
                    Spacer()
                    Button(role: .destructive) { update { $0.removeAll { $0.id == s.id } } } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
                Stepper("Fußweg: \(s.walk) min", value: Binding(
                    get: { s.walk },
                    set: { v in update { l in if let i = l.firstIndex(where: { $0.id == s.id }) { l[i].walk = v } } }), in: 0...30)
                TextField("Nur Linien, z. B. 5, 11 (leer = alle)", text: Binding(
                    get: { s.lines },
                    set: { v in update { l in if let i = l.firstIndex(where: { $0.id == s.id }) { l[i].lines = v } } }))
                TextField("Nur Richtung, z. B. Hbf (leer = alle)", text: Binding(
                    get: { s.dir },
                    set: { v in update { l in if let i = l.firstIndex(where: { $0.id == s.id }) { l[i].dir = v } } }))
            }
            .padding(.vertical, 4)
        }
        HStack {
            TextField("Haltestelle suchen, z. B. Regensburg Arnulfsplatz", text: $query)
                .onSubmit { Task { await search() } }
            if searching { ProgressView() }
            else { Button("Suchen") { Task { await search() } }.disabled(query.count < 3) }
        }
        ForEach(results) { r in
            Button {
                update { l in if !l.contains(where: { $0.id == r.id }) { l.append(r) } }
                results = []; query = ""
            } label: {
                Label(r.name, systemImage: "plus.circle.fill")
            }
        }
    }

    private func search() async {
        searching = true
        results = await TransitService.shared.search(query)
        searching = false
    }
}
