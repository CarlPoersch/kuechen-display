import SwiftUI

// ============================================================
// Sport-Bucket: Fußball und Tennis live.
// Einstellungen: fb / tn (an/aus).
// Welche Vereine und Turniere kommen, legt vorerst der Server fest
// (Bayern, Champions League, DFB-Team, ATP ab 250 mit Deutschen …).
// ============================================================
enum SportBucket {
    static let kind = BucketKind(
        id: "sport", name: "Sport", symbol: "sportscourt", tint: .green, art: .glance,
        interests: ["sport"], blurb: "Live-Ticker für Fußball und Tennis.",
        glance: { inst, size in AnyView(SportGlance(sports: chosen(inst.config), size: size)) },
        detail: { inst in AnyView(SportDetail(sports: chosen(inst.config))) },
        settings: { binding in AnyView(SportSettings(config: binding)) }
    )

    static func chosen(_ c: [String: JSON]) -> Set<String> {
        var s = Set<String>()
        if c["fb"]?.bool ?? true { s.insert("fb") }
        if c["tn"]?.bool ?? true { s.insert("tn") }
        return s
    }

    /// Startseite: erst das wichtigste Spiel jeder Sportart, dann der Rest
    static func pick(_ all: [Match], count: Int) -> [Match] {
        let now = Date()
        let relevant = all.filter { $0.state != "post" || now.timeIntervalSince($0.start) < 20 * 3600 }
        var out: [Match] = []
        for sp in ["fb", "tn"] { if let m = relevant.first(where: { $0.sport == sp }) { out.append(m) } }
        for m in relevant where !out.contains(where: { $0.id == m.id }) { out.append(m) }
        let order = ["in": 0, "pre": 1, "post": 2]
        return Array(out.prefix(count)).sorted { (order[$0.state] ?? 3) < (order[$1.state] ?? 3) }
    }
}

struct SportGlance: View {
    let sports: Set<String>
    let size: BucketSize
    @ObservedObject private var feed = FeedService.shared

    var body: some View {
        content.refreshing(every: { FeedService.shared.sportInterval }) { await FeedService.shared.loadSport() }
    }

    @ViewBuilder private var content: some View {
        if let f = feed.sport {
            let list = SportBucket.pick(f.matches.filter { sports.contains($0.sport) }, count: size == .s ? 1 : size == .m ? 3 : 6)
            if list.isEmpty {
                Text("Gerade keine Spiele").foregroundColor(Theme.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(list) { MatchRow(match: $0, compact: true) }
                }
            }
        } else {
            Text("Lädt …").foregroundColor(Theme.secondary)
        }
    }
}

/// Eine Zeile: Status links, zwei Teams/Spieler, Stand rechts
struct MatchRow: View {
    let match: Match
    var compact = false

    private var status: some View {
        Group {
            if match.isLive {
                Text(match.sport == "fb" ? match.detail : "LIVE")
                    .font(.caption.weight(.bold).monospacedDigit()).foregroundColor(.red)
            } else if match.state == "pre" {
                Text(Fmt.when(match.start)).font(.caption.monospacedDigit()).foregroundColor(Theme.secondary)
            } else {
                Text(match.detail.isEmpty ? "Ende" : match.detail).font(.caption).foregroundColor(Theme.secondary)
            }
        }
        .lineLimit(2).multilineTextAlignment(.leading)
        .frame(width: compact ? 58 : 70, alignment: .leading)
    }

    private func line(_ s: Match.Side, _ o: Match.Side) -> some View {
        HStack(spacing: 6) {
            Text(s.n + s.flag).fontWeight(s.win == true ? .semibold : .regular).lineLimit(1)
            if let r = s.r, !compact { Text("\(r)").font(.caption2).foregroundColor(Theme.secondary) }
            Spacer(minLength: 4)
            if match.sport == "tn", let sets = s.sets, !sets.isEmpty {
                ForEach(Array(sets.enumerated()), id: \.offset) { i, v in
                    let won = i < (o.sets ?? []).count && v > (o.sets ?? [])[i]
                    Text("\(Int(v))").font(.subheadline.monospacedDigit())
                        .fontWeight(won ? .semibold : .regular)
                        .foregroundColor(won ? .primary : Theme.secondary)
                        .frame(width: 14)
                }
            } else if let sc = s.score {
                Text(sc).font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .font(compact ? .subheadline : .body)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            status
            VStack(alignment: .leading, spacing: 2) {
                if !compact {
                    Text(([match.comp, match.round].compactMap { $0 }).joined(separator: " · "))
                        .font(.caption2.weight(.semibold)).foregroundColor(Theme.secondary).textCase(.uppercase)
                }
                line(match.a, match.b)
                line(match.b, match.a)
            }
        }
    }
}

struct SportDetail: View {
    let sports: Set<String>
    @ObservedObject private var feed = FeedService.shared

    var body: some View {
        let all = (feed.sport?.matches ?? []).filter { sports.contains($0.sport) }
        List {
            if feed.sport == nil { ProgressView() }
            else if all.isEmpty { Text("Gerade keine Spiele").foregroundColor(Theme.secondary) }
            section("Live", all.filter { $0.isLive })
            section("Demnächst", all.filter { $0.state == "pre" })
            section("Ergebnisse", all.filter { $0.state == "post" })
        }
        .listStyle(.insetGrouped)
        .refreshing(every: { FeedService.shared.sportInterval }) { await FeedService.shared.loadSport() }
    }

    @ViewBuilder private func section(_ title: String, _ list: [Match]) -> some View {
        if !list.isEmpty {
            Section(header: Text(title)) {
                ForEach(list) { m in
                    NavigationLink(destination: MatchDetailView(match: m)) { MatchRow(match: m).padding(.vertical, 4) }
                }
            }
        }
    }
}

struct SportSettings: View {
    @Binding var config: [String: JSON]
    var body: some View {
        Toggle("Fußball", isOn: $config.flag("fb"))
        Toggle("Tennis", isOn: $config.flag("tn"))
    }
}

// MARK: Spieldetails

struct MatchDetailView: View {
    let match: Match
    @State private var detail: MatchDetail?
    @State private var tab = 0
    @ObservedObject private var feed = FeedService.shared

    /// Aktueller Stand aus der Liste (Tennis hat keine eigenen Details)
    private var live: Match { feed.sport?.matches.first { $0.id == match.id } ?? match }

    var body: some View {
        List {
            Section { header.listRowBackground(Color.clear) }
            if live.sport == "tn" {
                Section(header: Text("Sätze")) { MatchRow(match: live).padding(.vertical, 6) }
                if let v = live.venue { Section(header: Text("Ort")) { Text(v) } }
                if let n = live.note { Section { Text(n).foregroundColor(Theme.secondary) } }
            } else if let d = detail {
                Picker("", selection: $tab) {
                    Text("Ticker").tag(0); Text("Statistik").tag(1); Text("Aufstellung").tag(2)
                }
                .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                if tab == 0 { events(d) } else if tab == 1 { stats(d) } else { lineups(d) }
                if d.venue != nil || d.ref != nil {
                    Section {
                        if let v = d.venue { Label(v, systemImage: "mappin.and.ellipse") }
                        if let r = d.ref { Label("Schiedsrichter: " + r, systemImage: "person") }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(live.comp)
        .navigationBarTitleDisplayMode(.inline)
        .refreshing(every: { live.isLive ? 30 : 600 }) { await load() }
    }

    private func load() async {
        await feed.loadSport()
        guard live.sport == "fb", let lg = live.lg, let id = live.eid else { return }
        if let d = try? await feed.match(lg: lg, id: id) { detail = d }
    }

    private var header: some View {
        VStack(spacing: 6) {
            if let r = live.round { Text(r.uppercased()).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary) }
            HStack(alignment: .center) {
                Text(live.a.n + live.a.flag).font(.title3.weight(.semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                VStack(spacing: 2) {
                    if live.sport == "fb" && live.state != "pre" {
                        Text("\(live.a.score ?? "-") : \(live.b.score ?? "-")").font(.system(size: 44, weight: .bold).monospacedDigit())
                    } else if live.state == "pre" {
                        Text(Fmt.hhmm(live.start)).font(.system(size: 34, weight: .semibold).monospacedDigit())
                    } else {
                        Text("vs").font(.title2).foregroundColor(Theme.secondary)
                    }
                    Text(live.isLive ? (live.sport == "fb" ? live.detail : "LIVE") : live.state == "pre" ? Fmt.dayLabel(live.start) : (live.detail.isEmpty ? "Ende" : live.detail))
                        .font(.subheadline.weight(live.isLive ? .bold : .regular))
                        .foregroundColor(live.isLive ? .red : Theme.secondary)
                    if let ht = detail?.h.ht, let at = detail?.a.ht, live.state != "pre" {
                        Text("Halbzeit \(ht):\(at)").font(.caption).foregroundColor(Theme.secondary)
                    }
                }
                .frame(minWidth: 120)
                Text(live.b.n + live.b.flag).font(.title3.weight(.semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder private func events(_ d: MatchDetail) -> some View {
        Section {
            if d.events.isEmpty { Text(d.state == "pre" ? "Noch nicht angepfiffen" : "Noch keine Ereignisse").foregroundColor(Theme.secondary) }
            ForEach(Array(d.events.reversed().enumerated()), id: \.offset) { _, e in
                HStack(spacing: 10) {
                    Text(e.min).font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary).frame(width: 46, alignment: .leading)
                    Text(icon(e.kind)).frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.who.isEmpty ? label(e.kind) : e.who).fontWeight(e.kind == "goal" || e.kind == "pen" ? .semibold : .regular)
                        Text([e.side == "h" ? d.h.n : d.a.n, e.extra].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.footnote).foregroundColor(Theme.secondary)
                    }
                }
            }
        }
    }

    private func icon(_ k: String) -> String {
        ["goal": "⚽️", "pen": "⚽️", "own": "⚽️", "yellow": "🟨", "red": "🟥", "sub": "🔄"][k] ?? "•"
    }
    private func label(_ k: String) -> String {
        ["goal": "Tor", "pen": "Elfmeter", "own": "Eigentor", "yellow": "Gelbe Karte", "red": "Rote Karte", "sub": "Wechsel"][k] ?? ""
    }

    @ViewBuilder private func stats(_ d: MatchDetail) -> some View {
        Section {
            if d.stats.isEmpty { Text("Noch keine Statistik").foregroundColor(Theme.secondary) }
            ForEach(Array(d.stats.enumerated()), id: \.offset) { _, r in
                if r.count == 3 {
                    HStack {
                        Text(r[1]).font(.body.monospacedDigit().weight(.semibold)).frame(width: 60, alignment: .leading)
                        Spacer(); Text(r[0]).foregroundColor(Theme.secondary); Spacer()
                        Text(r[2]).font(.body.monospacedDigit().weight(.semibold)).frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder private func lineups(_ d: MatchDetail) -> some View {
        if d.lineups.h == nil && d.lineups.a == nil {
            Section { Text("Aufstellung noch nicht bekannt").foregroundColor(Theme.secondary) }
        }
        team(d.h.n, d.lineups.h)
        team(d.a.n, d.lineups.a)
    }

    @ViewBuilder private func team(_ name: String, _ lineup: MatchDetail.Lineup?) -> some View {
        if let l = lineup {
            Section(header: Text(name + (l.form.isEmpty ? "" : " · " + l.form))) {
                ForEach(l.xi, id: \.self) { p in
                    HStack {
                        Text(p.nr).font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary).frame(width: 30, alignment: .leading)
                        Text(p.n)
                        Spacer()
                        Text(p.pos).font(.caption).foregroundColor(Theme.secondary)
                    }
                }
                if !l.bench.isEmpty {
                    Text("Bank: " + l.bench.map { $0.n }.joined(separator: ", ")).font(.footnote).foregroundColor(Theme.secondary)
                }
            }
        }
    }
}
