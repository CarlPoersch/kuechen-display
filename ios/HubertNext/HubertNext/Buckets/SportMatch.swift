import SwiftUI

// ============================================================
// Spielseite. Fußball wie bei Flashscore: Reiter Ticker · Aufstellung ·
// Statistik · Tabelle (nur Reiter mit Daten), Kopf mit Form und
// Tabellenplatz aus dem Wettbewerb des Spiels. Andere Sportarten wie bisher.
// Daten: Funktion „spiel“ (match, table). Design: docs/specs/2026-11-28-sport-spielseite-design.md
// ============================================================

struct MatchDetailView: View {
    let match: Match
    var follows: [SportFollow] = []
    @State private var detail: MatchDetail?
    @State private var tab: Tab?
    @ObservedObject private var feed = FeedService.shared
    @Environment(\.horizontalSizeClass) private var hSize

    enum Tab: Hashable { case ticker, lineup, stats, table }

    /// Aktueller Stand aus der Liste (Tennis hat keine eigenen Details)
    private var live: Match { feed.current(match.id) ?? match }
    private var wide: Bool { hSize == .regular }

    // MARK: Tabelle des Wettbewerbs

    private var tableKey: String? {
        guard live.sport == "fb" else { return nil }
        if let L = live.L, L.hasPrefix("soccer/") { return L }
        return live.lg.map { "soccer/" + $0 }
    }
    private var homeID: String? { detail?.h.id ?? live.a.id }
    private var awayID: String? { detail?.a.id ?? live.b.id }
    /// Tabelle nur, wenn beide bzw. eines der Teams darin steht (sonst z. B. Pokal oder K.-o.-Runde)
    private var table: LeagueTable? {
        guard let k = tableKey, let t = feed.tables[k], !t.isEmpty else { return nil }
        return t.row(homeID) != nil || t.row(awayID) != nil ? t : nil
    }

    // MARK: Reiter

    private var tabs: [Tab] {
        guard let d = detail else { return table != nil ? [.table] : [] }
        var out: [Tab] = []
        if d.state != "pre" || !d.events.isEmpty { out.append(.ticker) }
        if d.lineups.h != nil || d.lineups.a != nil { out.append(.lineup) }
        if !d.stats.isEmpty { out.append(.stats) }
        if table != nil { out.append(.table) }
        return out
    }
    /// Start-Reiter: vor Anpfiff Aufstellung (sonst Tabelle), danach Ticker
    private var current: Tab? {
        if let t = tab, tabs.contains(t) { return t }
        let pref: [Tab] = live.state == "pre" ? [.lineup, .table, .ticker, .stats] : [.ticker, .lineup, .stats, .table]
        return pref.first { tabs.contains($0) }
    }
    private func title(_ t: Tab) -> String {
        switch t { case .ticker: return "Ticker"; case .lineup: return "Aufstellung"; case .stats: return "Statistik"; case .table: return "Tabelle" }
    }

    var body: some View {
        List {
            Section { (live.isRace ? AnyView(raceHeader) : AnyView(header)).listRowBackground(Color.clear) }
            if live.isRace {
                raceSections
            } else if live.sport != "fb" && live.sport != "tn" {
                // Basketball, Eishockey, Football, Baseball: Stand oben, dazu Ort
                if let v = live.venue { Section(header: Text("Ort")) { Label(v, systemImage: "mappin.and.ellipse") } }
                Section { Text(live.comp + (live.round.map { " · " + $0 } ?? "")).foregroundColor(Theme.secondary) }
            } else if live.sport == "tn" {
                Section(header: Text("Sätze")) { MatchRow(match: live, follows: follows).padding(.vertical, 6) }
                if let v = live.venue { Section(header: Text("Ort")) { Text(v) } }
                if let n = live.note { Section { Text(n).foregroundColor(Theme.secondary) } }
            } else if detail == nil && table == nil {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                if tabs.count > 1 {
                    Picker("", selection: Binding(get: { current ?? .ticker }, set: { tab = $0 })) {
                        ForEach(tabs, id: \.self) { Text(title($0)).tag($0) }
                    }
                    .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                switch current {
                case .ticker?: if let d = detail { ticker(d) }
                case .lineup?: if let d = detail { lineups(d) }
                case .stats?: if let d = detail { stats(d) }
                case .table?: tableTab
                case nil:
                    Section { Text(live.state == "pre" ? "Noch keine Infos zum Spiel" : "Keine Details verfügbar").foregroundColor(Theme.secondary) }
                }
                if let d = detail, d.venue != nil || d.ref != nil {
                    Section {
                        if let v = d.venue { Label(v, systemImage: "mappin.and.ellipse") }
                        if let r = d.ref { Label("Schiedsrichter: " + r, systemImage: "person") }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(live.comp)
        .navigationBarTitleDisplayMode(.inline)
        .refreshing(every: { live.isLive ? 30 : 600 }) { await load() }
    }

    private func load() async {
        if !follows.isEmpty { await feed.loadSport(leagues: SportBucket.leagues(follows)) }
        guard live.sport == "fb" else { return }
        if let lg = live.lg, let id = live.eid, let d = try? await feed.match(lg: lg, id: id) { detail = d }
        if let k = tableKey { await feed.loadTable(k) }
    }

    // MARK: Kopf

    private var header: some View {
        VStack(spacing: 6) {
            if let r = live.round { Text(r.uppercased()).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary) }
            HStack(alignment: .top) {
                team(live.a, id: homeID)
                VStack(spacing: 2) {
                    if live.hasScore && live.state != "pre" {
                        Text("\(live.a.score ?? "-") : \(live.b.score ?? "-")").font(.system(size: 44, weight: .bold).monospacedDigit())
                    } else if live.state == "pre" {
                        Text(Fmt.hhmm(live.start)).font(.system(size: 34, weight: .semibold).monospacedDigit())
                    } else {
                        Text("vs").font(.title2).foregroundColor(Theme.secondary)
                    }
                    Text(live.isLive ? (live.sport == "tn" ? "LIVE" : live.detailDE) : live.state == "pre" ? Fmt.dayLabel(live.start) : (live.detail.isEmpty ? "Ende" : live.detailDE))
                        .font(.subheadline.weight(live.isLive ? .bold : .regular))
                        .foregroundColor(live.isLive ? .red : Theme.secondary)
                    if let ht = detail?.h.ht, let at = detail?.a.ht, live.state != "pre" {
                        Text("Halbzeit \(ht):\(at)").font(.caption).foregroundColor(Theme.secondary)
                    }
                }
                .frame(minWidth: 120)
                team(live.b, id: awayID)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// Teamname, darunter Tabellenplatz und Form (nur wenn der Wettbewerb eine Tabelle hat)
    private func team(_ s: Match.Side, id: String?) -> some View {
        VStack(spacing: 6) {
            Text(s.n + s.flag).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.8)
            if let t = table, let r = t.row(id) {
                Text("\(r.p). Platz").font(.caption).foregroundColor(Theme.secondary)
                if let f = t.form[r.id], !f.isEmpty { FormDots(form: f, size: 15) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: Ticker (zweiseitig)

    @ViewBuilder private func ticker(_ d: MatchDetail) -> some View {
        Section {
            if d.events.isEmpty {
                Text(d.state == "pre" ? "Noch nicht angepfiffen" : "Noch keine Ereignisse").foregroundColor(Theme.secondary)
            }
            let list = Array(d.events.reversed())
            ForEach(Array(list.enumerated()), id: \.offset) { i, e in
                // Trennlinie zur Halbzeit (zwischen 1. und 2. Hälfte, neueste oben)
                if i > 0 && Self.minute(list[i - 1].min) > 45 && Self.minute(e.min) <= 45 {
                    halftimeRow(d)
                }
                eventRow(e)
            }
        }
    }

    /// „45'+2'“ → 45 (zählt zur 1. Hälfte), „73'“ → 73
    static func minute(_ s: String) -> Int {
        Int(s.prefix { $0.isNumber }) ?? 0
    }

    private func halftimeRow(_ d: MatchDetail) -> some View {
        HStack {
            VStack { Divider() }
            Text("Halbzeit" + ((d.h.ht).flatMap { h in d.a.ht.map { " \(h):\($0)" } } ?? ""))
                .font(.caption.weight(.semibold)).foregroundColor(Theme.secondary).fixedSize()
            VStack { Divider() }
        }
    }

    private func eventRow(_ e: MatchDetail.Event) -> some View {
        let home = e.side == "h"
        return HStack(alignment: .center, spacing: 8) {
            Group { if home { eventText(e, home: true) } else { Spacer(minLength: 0) } }
                .frame(maxWidth: .infinity, alignment: .trailing)
            if home { eventIcon(e.kind) }
            Text(e.min).font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundColor(Theme.secondary).frame(width: 50)
            if !home { eventIcon(e.kind) }
            Group { if !home { eventText(e, home: false) } else { Spacer(minLength: 0) } }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func eventText(_ e: MatchDetail.Event, home: Bool) -> some View {
        VStack(alignment: home ? .trailing : .leading, spacing: 1) {
            Text(e.who.isEmpty ? label(e.kind) : e.who)
                .fontWeight(["goal", "pen", "own"].contains(e.kind) ? .semibold : .regular)
                .lineLimit(2).multilineTextAlignment(home ? .trailing : .leading)
            let extra = [e.kind == "pen" ? "Elfmeter" : e.kind == "own" ? "Eigentor" : "", e.extra].filter { !$0.isEmpty }.joined(separator: " · ")
            if !extra.isEmpty {
                Text(extra).font(.footnote).foregroundColor(Theme.secondary)
                    .lineLimit(2).multilineTextAlignment(home ? .trailing : .leading)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder private func eventIcon(_ k: String) -> some View {
        switch k {
        case "yellow": CardShape(color: .yellow, second: false).frame(width: 22)
        case "red": CardShape(color: .red, second: false).frame(width: 22)
        case "yellowred": CardShape(color: .red, second: true).frame(width: 22)
        case "sub": Image(systemName: "arrow.left.arrow.right").font(.caption.weight(.bold)).foregroundColor(Theme.secondary).frame(width: 22)
        default: Text("⚽️").font(.subheadline).frame(width: 22)
        }
    }

    private func label(_ k: String) -> String {
        ["goal": "Tor", "pen": "Elfmeter", "own": "Eigentor", "yellow": "Gelbe Karte", "yellowred": "Gelb-Rot",
         "red": "Rote Karte", "sub": "Wechsel"][k] ?? ""
    }

    // MARK: Statistik (Balken)

    @ViewBuilder private func stats(_ d: MatchDetail) -> some View {
        Section {
            ForEach(Array(d.stats.enumerated()), id: \.offset) { _, r in
                if r.count == 3 { StatBar(label: r[0], home: r[1], away: r[2]).padding(.vertical, 4) }
            }
        }
    }

    // MARK: Aufstellung

    @ViewBuilder private func lineups(_ d: MatchDetail) -> some View {
        let h = d.lineups.h.flatMap { PitchLayout.lines($0) }
        let a = d.lineups.a.flatMap { PitchLayout.lines($0) }
        if let h = h, let a = a {
            let pitch = PitchView(home: h, away: a, homeName: d.h.n, awayName: d.a.n,
                                  homeForm: d.lineups.h?.form ?? "", awayForm: d.lineups.a?.form ?? "")
            if wide {
                // iPad: Feld links, Bank rechts
                Section {
                    HStack(alignment: .top, spacing: 20) {
                        pitch.frame(maxWidth: 520)
                        VStack(alignment: .leading, spacing: 18) {
                            benchBlock(d.h.n, d.lineups.h)
                            benchBlock(d.a.n, d.lineups.a)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                Section { pitch }
                benchSection(d.h.n, d.lineups.h)
                benchSection(d.a.n, d.lineups.a)
            }
        } else {
            // Liste, wenn das Feld nicht sicher aufgestellt werden kann
            listTeam(d.h.n, d.lineups.h)
            listTeam(d.a.n, d.lineups.a)
        }
    }

    @ViewBuilder private func benchSection(_ name: String, _ l: MatchDetail.Lineup?) -> some View {
        if let l = l, !l.bench.isEmpty {
            Section(header: Text("Bank · " + name)) {
                ForEach(l.bench, id: \.self) { benchRow($0) }
            }
        }
    }

    @ViewBuilder private func benchBlock(_ name: String, _ l: MatchDetail.Lineup?) -> some View {
        if let l = l, !l.bench.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("BANK · " + name.uppercased()).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                ForEach(l.bench, id: \.self) { benchRow($0) }
            }
        }
    }

    private func benchRow(_ p: MatchDetail.Player) -> some View {
        HStack(spacing: 8) {
            Text(p.nr).font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary).frame(width: 28, alignment: .leading)
            Text(p.n).font(.subheadline).fontWeight(p.has("in") ? .semibold : .regular).lineLimit(1)
            playerMarks(p)
            Spacer(minLength: 4)
            if p.has("in"), let m = p.subMinute {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up").font(.caption2.weight(.bold))
                    Text(m).font(.caption.monospacedDigit())
                }
                .foregroundColor(Color(UIColor.systemGreen))
            }
        }
    }

    /// Tore und Karten hinter dem Namen (Liste und Bank)
    @ViewBuilder private func playerMarks(_ p: MatchDetail.Player) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<p.goals, id: \.self) { _ in Text("⚽️").font(.caption2) }
            if p.has("red") || p.has("yellowred") { CardShape(color: .red, second: p.has("yellowred")) }
            else if p.has("yellow") { CardShape(color: .yellow, second: false) }
        }
    }

    @ViewBuilder private func listTeam(_ name: String, _ lineup: MatchDetail.Lineup?) -> some View {
        if let l = lineup {
            Section(header: Text(name + (l.form.isEmpty ? "" : " · " + l.form))) {
                ForEach(l.xi, id: \.self) { p in
                    HStack(spacing: 8) {
                        Text(p.nr).font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary).frame(width: 30, alignment: .leading)
                        Text(p.n)
                        playerMarks(p)
                        Spacer()
                        if let m = p.subMinute {
                            HStack(spacing: 2) { Image(systemName: "arrow.down").font(.caption2.weight(.bold)); Text(m) }
                                .font(.caption.monospacedDigit()).foregroundColor(Theme.secondary)
                        }
                        Text(p.pos).font(.caption).foregroundColor(Theme.secondary)
                    }
                }
            }
            if !l.bench.isEmpty {
                Section(header: Text("Bank · " + name)) { ForEach(l.bench, id: \.self) { benchRow($0) } }
            }
        }
    }

    // MARK: Tabelle

    @ViewBuilder private var tableTab: some View {
        if let t = table, let g = t.group(with: homeID ?? awayID) ?? t.group(with: awayID) {
            TableSection(table: t, group: g, title: g.n ?? live.comp,
                         highlight: Set([homeID, awayID].compactMap { $0 }),
                         favs: SportBucket.favTeams(follows), wide: wide)
        }
    }

    // MARK: Formel 1

    private var raceHeader: some View {
        VStack(spacing: 6) {
            Text("🏎️").font(.system(size: 44))
            Text(live.a.n).font(.title2.weight(.bold))
            Text([live.venue, live.b.n.isEmpty ? nil : live.b.n].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
            Text(live.isLive ? "Rennen läuft" : live.state == "pre" ? "Rennen " + Fmt.dayLabel(live.start) + " " + Fmt.hhmm(live.start) : "Ergebnis")
                .font(.subheadline.weight(live.isLive ? .bold : .regular))
                .foregroundColor(live.isLive ? .red : Theme.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    @ViewBuilder private var raceSections: some View {
        if let field = live.field, !field.isEmpty {
            Section(header: Text("Ergebnis")) {
                ForEach(field, id: \.self) { d in
                    let fav = SportBucket.favDriver(d.id, follows)
                    HStack(spacing: 12) {
                        Text("\(d.pos)").font(.headline.monospacedDigit()).frame(width: 28, alignment: .leading)
                            .foregroundColor(d.pos <= 3 ? Theme.accent : .primary)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(d.n).fontWeight(fav ? .semibold : .regular)
                                if fav { Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow) }
                            }
                            if let t = d.t { Text(t).font(.caption).foregroundColor(Theme.secondary) }
                        }
                        Spacer()
                        if let c = d.c { Text(c).font(.caption.monospaced()).foregroundColor(Theme.secondary) }
                    }
                }
            }
        }
        if let ss = live.sessions, !ss.isEmpty {
            Section(header: Text("Zeitplan")) {
                ForEach(ss, id: \.self) { x in
                    HStack {
                        Text(x.n)
                        Spacer()
                        Text(Fmt.dayLabel(x.date) + " " + Fmt.hhmm(x.date)).foregroundColor(Theme.secondary).monospacedDigit()
                    }
                }
            }
        }
    }
}

/// Statistik-Zeile: Werte links/rechts, Bezeichnung mittig, darunter zwei Balken zur Mitte hin
struct StatBar: View {
    let label: String
    let home: String
    let away: String

    private var percent: Bool { label == "Ballbesitz" }
    private func value(_ s: String) -> Double { Double(s.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private func shown(_ s: String) -> String {
        guard percent else { return s }
        return "\(Int(value(s).rounded())) %"
    }

    var body: some View {
        let a = value(home), b = value(away)
        let total = a + b
        let fa = total > 0 ? a / total : 0.5, fb = total > 0 ? b / total : 0.5
        VStack(spacing: 6) {
            HStack {
                Text(shown(home)).font(.subheadline.monospacedDigit().weight(a >= b ? .semibold : .regular))
                Spacer()
                Text(label).font(.subheadline).foregroundColor(Theme.secondary)
                Spacer()
                Text(shown(away)).font(.subheadline.monospacedDigit().weight(b >= a ? .semibold : .regular))
            }
            GeometryReader { g in
                let half = (g.size.width - 6) / 2
                HStack(spacing: 6) {
                    ZStack(alignment: .trailing) {
                        Capsule().fill(Color(UIColor.systemGray5))
                        Capsule().fill(a > b ? Theme.accent : Color(UIColor.systemGray3)).frame(width: max(4, half * fa))
                    }
                    .frame(width: half)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(UIColor.systemGray5))
                        Capsule().fill(b > a ? Theme.accent : Color(UIColor.systemGray3)).frame(width: max(4, half * fb))
                    }
                    .frame(width: half)
                }
            }
            .frame(height: 6)
        }
    }
}
