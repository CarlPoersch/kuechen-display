import SwiftUI

// ============================================================
// Sport-Bucket – personalisierbar wie Apple Sports:
// Ligen und Turniere wählen, je Liga „alle Spiele“ oder nur Favoriten
// (Vereine, Spieler, Fahrer). Sportarten: Fußball, Tennis, Basketball,
// Eishockey (NHL, DEL), American Football, Baseball, Formel 1.
// Einstellungen: leagues = [{ id, mode, fav: [IDs], names: [Namen] }]
// (ältere Karten mit fb/tn werden beim Lesen umgerechnet).
// ============================================================

/// Eine gewählte Liga mit Anzeige-Modus und Favoriten
struct SportPick: Hashable, Identifiable {
    var id: String                // Liga, z. B. "soccer/ger.1", "tennis/atp", "f1"
    var mode: String = "all"      // all · fav (nur Favoriten) · de (deutsche Vereine bzw. Deutsche & Endspiele)
    var fav: [String] = []        // Team-, Spieler- oder Fahrer-IDs
    var names: [String] = []      // Namen (Tennis, Nationalteams)

    var json: JSON {
        .object(["id": .string(id), "mode": .string(mode),
                 "fav": .array(fav.map { .string($0) }), "names": .array(names.map { .string($0) })])
    }

    init(id: String, mode: String = "all", fav: [String] = [], names: [String] = []) {
        self.id = id; self.mode = mode; self.fav = fav; self.names = names
    }

    init?(_ j: JSON) {
        guard let o = j.object, let id = o["id"]?.string else { return nil }
        self.id = id
        mode = o["mode"]?.string ?? "all"
        fav = (o["fav"]?.array ?? []).compactMap(\.string)
        names = (o["names"]?.array ?? []).compactMap(\.string)
    }

    var sport: String { SportBucket.sport(of: id) }

    /// Ist diese Seite ein Favorit?
    func isFav(_ s: Match.Side) -> Bool {
        if let i = s.id, fav.contains(i) { return true }
        let n = (s.full ?? s.n).lowercased(), short = s.n.lowercased()
        return names.contains { let q = $0.lowercased(); return n.contains(q) || short == q }
    }

    func hasFav(_ m: Match) -> Bool {
        if m.isRace { return (m.field ?? []).contains { d in d.id.map { fav.contains($0) } ?? false } }
        return isFav(m.a) || isFav(m.b)
    }

    /// Soll das Spiel gezeigt werden?
    func shows(_ m: Match) -> Bool {
        if m.isRace { return true }
        switch mode {
        case "fav": return hasFav(m)
        case "de": return m.sport == "tn" ? (m.a.c == "GER" || m.b.c == "GER" || m.late == true || hasFav(m)) : (m.de == true || hasFav(m))
        default: return true
        }
    }
}

enum SportBucket {
    static let kind = BucketKind(
        id: "sport", name: "Sport", symbol: "sportscourt", tint: .green, art: .glance,
        interests: ["sport"], blurb: "Live-Ergebnisse deiner Ligen, Vereine und Spieler.",
        glance: { inst, size in AnyView(SportGlance(picks: picks(inst.config), size: size)) },
        detail: { inst in AnyView(SportDetail(picks: picks(inst.config))) },
        itemLinks: true,
        settings: { binding in AnyView(SportSettings(config: binding)) }
    )

    static let emoji = ["fb": "⚽️", "tn": "🎾", "bb": "🏀", "ih": "🏒", "af": "🏈", "bs": "⚾️", "f1": "🏎️"]
    static let sportName = ["fb": "Fußball", "tn": "Tennis", "bb": "Basketball", "ih": "Eishockey", "af": "Football", "bs": "Baseball", "f1": "Formel 1"]

    static func sport(of league: String) -> String {
        if league == "f1" { return "f1" }
        if league == "del" { return "ih" }
        switch league.split(separator: "/").first ?? "" {
        case "soccer": return "fb"
        case "tennis": return "tn"
        case "basketball": return "bb"
        case "hockey": return "ih"
        case "football": return "af"
        case "baseball": return "bs"
        default: return "fb"
        }
    }

    /// Gewählte Ligen. Fehlt die Liste (ältere Karte), gilt die bisherige feste Auswahl.
    static func picks(_ c: [String: JSON]) -> [SportPick] {
        if let list = c["leagues"]?.array { return list.compactMap { SportPick($0) } }
        var out: [SportPick] = []
        if c["fb"]?.bool ?? true {
            out += [SportPick(id: "soccer/ger.1", mode: "fav", fav: ["132"]),
                    SportPick(id: "soccer/ger.dfb_pokal"), SportPick(id: "soccer/uefa.champions"),
                    SportPick(id: "soccer/uefa.europa", mode: "de"), SportPick(id: "soccer/uefa.europa.conf", mode: "de")]
            out += ["soccer/fifa.world", "soccer/fifa.worldq.uefa", "soccer/uefa.euro", "soccer/uefa.euroq", "soccer/uefa.nations", "soccer/fifa.friendly"]
                .map { SportPick(id: $0, mode: "fav", names: ["Deutschland"]) }
        }
        if c["tn"]?.bool ?? true {
            out += [SportPick(id: "tennis/atp", mode: "de"), SportPick(id: "tennis/wta", mode: "de")]
        }
        return out
    }

    static func store(_ picks: [SportPick], in c: inout [String: JSON]) {
        c["leagues"] = .array(picks.map(\.json))
        c["fb"] = nil; c["tn"] = nil
    }

    /// Gefilterte Spiele: nur die gewählten Ligen, je nach Modus nur Favoriten
    static func filter(_ all: [Match], _ picks: [SportPick]) -> [Match] {
        let byId = Dictionary(picks.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return all.filter { m in byId[m.L ?? ""].map { $0.shows(m) } ?? false }
    }

    static func isFav(_ m: Match, _ picks: [SportPick]) -> Bool {
        picks.first { $0.id == m.L }?.hasFav(m) ?? false
    }

    /// Startseite: Live zuerst, dann Favoriten, dann der Rest; Ergebnisse höchstens 20 Std. alt
    static func pick(_ all: [Match], _ picks: [SportPick]) -> [Match] {
        let now = Date()
        let order = ["in": 0, "pre": 1, "post": 2]
        return all.filter { $0.state != "post" || now.timeIntervalSince($0.start) < 20 * 3600 }
            .sorted { a, b in
                let oa = order[a.state] ?? 3, ob = order[b.state] ?? 3
                if oa != ob { return oa < ob }
                let fa = isFav(a, picks), fb = isFav(b, picks)
                if fa != fb && a.state != "pre" { return fa }
                return a.state == "post" ? a.start > b.start : a.start < b.start
            }
    }
}

struct SportGlance: View {
    let picks: [SportPick]
    let size: BucketSize
    @ObservedObject private var feed = FeedService.shared
    @Environment(\.glanceSpace) private var space

    private var key: String { FeedService.key(picks.map(\.id)) }

    var body: some View {
        content.refreshing(id: key, every: { FeedService.shared.sportInterval(key) }) {
            await FeedService.shared.loadSport(leagues: picks.map(\.id))
        }
    }

    @ViewBuilder private var content: some View {
        if picks.isEmpty {
            Text("Wähle Ligen und Favoriten über den Regler oben rechts").foregroundColor(Theme.secondary)
        } else if let f = feed.sportFeeds[key] {
            let list = SportBucket.pick(SportBucket.filter(f.matches, picks), picks)
            if list.isEmpty {
                Text("Gerade keine Spiele").foregroundColor(Theme.secondary)
            } else {
                GlancePager(pages: Pages.split(list, height: space.height, row: 54)) { page in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(page.enumerated()), id: \.element.id) { i, m in
                            if i > 0 { Divider() }
                            // Jedes Spiel einzeln antippbar
                            NavigationLink(destination: MatchDetailView(match: m, picks: picks)) {
                                HStack(spacing: 6) {
                                    MatchRow(match: m, compact: true, picks: picks)
                                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                }
                                .padding(.vertical, 6).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } else {
            Text("Lädt …").foregroundColor(Theme.secondary)
        }
    }
}

/// Eine Zeile: Status links, zwei Teams/Spieler (oder Rennen), Stand rechts
struct MatchRow: View {
    let match: Match
    var compact = false
    var picks: [SportPick] = []

    private var pick: SportPick? { picks.first { $0.id == match.L } }

    private var status: some View {
        Group {
            if match.isLive {
                Text(match.sport == "tn" ? "LIVE" : match.detailDE)
                    .font(.caption.weight(.bold).monospacedDigit()).foregroundColor(.red)
            } else if match.state == "pre" {
                Text(Fmt.when(match.start)).font(.caption.monospacedDigit()).foregroundColor(Theme.secondary)
            } else {
                Text(match.detail.isEmpty ? "Ende" : match.detailDE).font(.caption).foregroundColor(Theme.secondary)
            }
        }
        .lineLimit(2).multilineTextAlignment(.leading)
        .frame(width: compact ? 58 : 70, alignment: .leading)
    }

    private func line(_ s: Match.Side, _ o: Match.Side) -> some View {
        let fav = pick?.isFav(s) ?? false
        return HStack(spacing: 6) {
            Text(s.n + s.flag).fontWeight(s.win == true || fav ? .semibold : .regular).lineLimit(1)
            if fav { Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow) }
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

    /// Formel 1: Rennen statt zwei Seiten
    private var race: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("🏎️ " + match.a.n).fontWeight(.semibold).lineLimit(1)
                Spacer(minLength: 4)
            }
            if let field = match.field, !field.isEmpty {
                let favs = field.filter { d in d.id.map { (pick?.fav ?? []).contains($0) } ?? false }
                let show = field.prefix(3).map { "\($0.pos). \($0.n)" } + favs.filter { $0.pos > 3 }.map { "⭐ \($0.pos). \($0.n)" }
                Text(show.joined(separator: " · ")).font(.caption).foregroundColor(Theme.secondary).lineLimit(compact ? 1 : 2)
            } else if let next = match.sessions?.first {
                Text(next.n + " · " + Fmt.when(next.date)).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
            }
        }
        .font(compact ? .subheadline : .body)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            status
            if match.isRace {
                race
            } else {
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
}

struct SportDetail: View {
    let picks: [SportPick]
    @State private var only = "alle"
    @ObservedObject private var feed = FeedService.shared

    private var key: String { FeedService.key(picks.map(\.id)) }
    /// Sportarten in der Auswahl, in fester Reihenfolge
    private var sports: [String] {
        let have = Set(picks.map(\.sport))
        return ["fb", "tn", "bb", "ih", "af", "bs", "f1"].filter(have.contains)
    }

    var body: some View {
        let all = SportBucket.filter(feed.sportFeeds[key]?.matches ?? [], picks).filter { only == "alle" || $0.sport == only }
        List {
            // Sportarten als Kapseln (bei vielen Sportarten passt kein Segment mehr)
            if sports.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("alle", "Alle")
                        ForEach(sports, id: \.self) { s in chip(s, (SportBucket.emoji[s] ?? "") + " " + (SportBucket.sportName[s] ?? s)) }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if picks.isEmpty { Text("Noch keine Ligen gewählt – oben rechts über den Regler einstellen.").foregroundColor(Theme.secondary) }
            else if feed.sportFeeds[key] == nil { ProgressView() }
            else if all.isEmpty { Text("Gerade keine Spiele").foregroundColor(Theme.secondary) }
            section("Live", all.filter { $0.isLive })
            section("Meine Favoriten", all.filter { !$0.isLive && $0.state == "pre" && SportBucket.isFav($0, picks) })
            section("Demnächst", all.filter { $0.state == "pre" && !SportBucket.isFav($0, picks) })
            section("Ergebnisse", all.filter { $0.state == "post" })
        }
        .listStyle(.insetGrouped)
        .refreshing(id: key, every: { FeedService.shared.sportInterval(key) }) { await FeedService.shared.loadSport(leagues: picks.map(\.id)) }
    }

    private func chip(_ id: String, _ title: String) -> some View {
        Button { withAnimation { only = id } } label: {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .foregroundColor(only == id ? .white : .primary)
                .background(Capsule().fill(only == id ? Theme.accent : Theme.card))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func section(_ title: String, _ list: [Match]) -> some View {
        if !list.isEmpty {
            Section(header: Text(title)) {
                ForEach(list) { m in
                    NavigationLink(destination: MatchDetailView(match: m, picks: picks)) { MatchRow(match: m, picks: picks).padding(.vertical, 4) }
                }
            }
        }
    }
}

struct MatchDetailView: View {
    let match: Match
    var picks: [SportPick] = []
    @State private var detail: MatchDetail?
    @State private var tab = 0
    @ObservedObject private var feed = FeedService.shared

    /// Aktueller Stand aus der Liste (Tennis hat keine eigenen Details)
    private var live: Match { feed.current(match.id) ?? match }

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
        if !picks.isEmpty { await feed.loadSport(leagues: picks.map(\.id)) }
        guard live.sport == "fb", let lg = live.lg, let id = live.eid else { return }
        if let d = try? await feed.match(lg: lg, id: id) { detail = d }
    }

    private var pick: SportPick? { picks.first { $0.id == live.L } }

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
                    let fav = d.id.map { (pick?.fav ?? []).contains($0) } ?? false
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

    private var header: some View {
        VStack(spacing: 6) {
            if let r = live.round { Text(r.uppercased()).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary) }
            HStack(alignment: .center) {
                Text(live.a.n + live.a.flag).font(.title3.weight(.semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
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
