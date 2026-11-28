import SwiftUI

// ============================================================
// Sport-Bucket – man folgt Vereinen, Nationalteams, Sportlern,
// Fahrern, Ländern oder ganzen Ligen (Suche wie bei den Haltestellen).
// Quellen über die Supabase-Funktion „sport“: ESPN, HockeyWeb, Formel 1.
// Einstellungen: follows = [{ kind, ref, name, sport, emoji, sub, leagues, mode }]
// (ältere Karten mit fb/tn bzw. leagues werden beim Lesen umgerechnet).
// ============================================================

/// Etwas, dem man folgt
struct SportFollow: Hashable {
    var kind: String          // team · nat · player · driver · country · league
    var ref: String           // ID der Quelle (Team, Spieler, Fahrer, Ländercode, Liga)
    var name: String
    var sport: String         // fb tn ih bb af bs f1
    var emoji: String
    var sub: String
    var leagues: [String]     // Wettbewerbe, in denen Hubert die Spiele zeigt
    var mode = "all"          // nur Ligen: all · de (deutsche Vereine bzw. Deutsche & Endspiele)

    var uid: String { kind + ":" + sport + ":" + ref }
    var isLeague: Bool { kind == "league" }

    init(kind: String, ref: String, name: String, sport: String, emoji: String, sub: String, leagues: [String], mode: String = "all") {
        self.kind = kind; self.ref = ref; self.name = name; self.sport = sport
        self.emoji = emoji; self.sub = sub; self.leagues = leagues; self.mode = mode
    }

    init(_ h: SportHit) {
        self.init(kind: h.kind, ref: h.id, name: h.name, sport: h.sport, emoji: h.emoji, sub: h.sub, leagues: h.leagues)
    }

    init?(_ j: JSON) {
        guard let o = j.object, let kind = o["kind"]?.string, let ref = o["ref"]?.string else { return nil }
        let sport = o["sport"]?.string ?? "fb"
        self.init(kind: kind, ref: ref, name: o["name"]?.string ?? "", sport: sport,
                  emoji: o["emoji"]?.string ?? (SportBucket.emoji[sport] ?? "🏆"), sub: o["sub"]?.string ?? "",
                  leagues: (o["leagues"]?.array ?? []).compactMap(\.string), mode: o["mode"]?.string ?? "all")
    }

    var json: JSON {
        .object(["kind": .string(kind), "ref": .string(ref), "name": .string(name), "sport": .string(sport),
                 "emoji": .string(emoji), "sub": .string(sub), "leagues": .array(leagues.map { .string($0) }), "mode": .string(mode)])
    }

    /// Passt eine Seite (Team oder Spieler) zu diesem Favoriten?
    func matches(_ s: Match.Side) -> Bool {
        if kind == "country" { return s.c == ref }
        if let i = s.id, i == ref { return true }
        let names = [s.full, s.n].compactMap { $0 }
        // Aus älteren Karten: Spieler nur mit Namensteil (z. B. „Zverev“)
        if kind == "player" && ref == name { return names.contains { $0.localizedCaseInsensitiveContains(name) } }
        return !name.isEmpty && names.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }
}

enum SportBucket {
    static let kind = BucketKind(
        id: "sport", name: "Sport", symbol: "sportscourt", tint: .green, art: .glance,
        interests: ["sport"], blurb: "Live-Ergebnisse deiner Vereine, Sportler und Ligen.",
        glance: { inst, size in AnyView(SportGlance(follows: follows(inst.config), size: size)) },
        detail: { inst in AnyView(SportDetail(follows: follows(inst.config))) },
        itemLinks: true,
        settings: { binding in AnyView(SportSettings(config: binding)) }
    )

    static let emoji = ["fb": "⚽️", "tn": "🎾", "bb": "🏀", "ih": "🏒", "af": "🏈", "bs": "⚾️", "f1": "🏎️"]
    static let sportName = ["fb": "Fußball", "tn": "Tennis", "bb": "Basketball", "ih": "Eishockey", "af": "Football", "bs": "Baseball", "f1": "Formel 1"]
    static let order = ["fb", "tn", "ih", "bb", "af", "bs", "f1"]

    static let natLeagues = ["soccer/fifa.world", "soccer/fifa.worldq.uefa", "soccer/uefa.euro", "soccer/uefa.euroq",
                             "soccer/uefa.nations", "soccer/fifa.friendly"]
    static let intlLeagues = ["soccer/uefa.champions", "soccer/uefa.europa", "soccer/uefa.europa.conf", "soccer/fifa.cwc"]

    static func sport(of league: String) -> String {
        if league == "f1" { return "f1" }
        if league == "del" { return "ih" }
        switch league.split(separator: "/").first ?? "" {
        case "soccer": return "fb"
        case "tennis": return "tn"
        case "basketball": return "bb"
        case "hockey", "hw": return "ih"
        case "football": return "af"
        case "baseball": return "bs"
        default: return "fb"
        }
    }

    static func leagueName(_ id: String) -> String {
        FeedService.shared.catalog.flatMap(\.leagues).first { $0.id == id }?.name ?? fallbackNames[id] ?? id
    }
    private static let fallbackNames = [
        "soccer/ger.1": "Bundesliga", "soccer/ger.dfb_pokal": "DFB-Pokal", "soccer/uefa.champions": "Champions League",
        "soccer/uefa.europa": "Europa League", "soccer/uefa.europa.conf": "Conference League", "soccer/fifa.cwc": "Klub-WM",
        "tennis/atp": "ATP (Herren)", "tennis/wta": "WTA (Damen)", "f1": "Formel 1", "hw/oberliga": "Oberliga", "hw/del": "DEL",
    ]

    // MARK: Gespeicherte Auswahl

    static func follows(_ c: [String: JSON]) -> [SportFollow] {
        if let list = c["follows"]?.array { return list.compactMap { SportFollow($0) } }
        return migrate(c)
    }

    static func store(_ f: [SportFollow], in c: inout [String: JSON]) {
        c["follows"] = .array(f.map(\.json))
        c["leagues"] = nil; c["fb"] = nil; c["tn"] = nil
    }

    /// Alle Wettbewerbe, die geladen werden müssen (ohne Doppelte, Reihenfolge bleibt)
    static func leagues(_ f: [SportFollow]) -> [String] {
        var seen = Set<String>()
        return f.flatMap(\.leagues).filter { seen.insert($0).inserted }
    }

    static func league(_ id: String, mode: String = "all") -> SportFollow {
        let sp = sport(of: id)
        return SportFollow(kind: "league", ref: id, name: leagueName(id), sport: sp, emoji: emoji[sp] ?? "🏆",
                           sub: (sportName[sp] ?? "") + " · Liga", leagues: [id], mode: mode)
    }

    /// Wettbewerbe, die zu einem Verein bzw. Team gehören (Liga, Pokal, Europapokal)
    static func defaultLeagues(team league: String, nat: Bool) -> [String] {
        if nat { return natLeagues }
        guard sport(of: league) == "fb" else { return [league] }
        if intlLeagues.contains(league) { return intlLeagues }
        return [league] + (league.hasPrefix("soccer/ger.") ? ["soccer/ger.dfb_pokal"] : []) + intlLeagues
    }

    /// Frühere Karten: feste Auswahl (fb/tn) bzw. Ligen mit Favoriten
    private static func migrate(_ c: [String: JSON]) -> [SportFollow] {
        guard let list = c["leagues"]?.array else {
            var out: [SportFollow] = []
            if c["fb"]?.bool ?? true {
                out.append(SportFollow(kind: "team", ref: "132", name: "FC Bayern", sport: "fb", emoji: "⚽️", sub: "Fußball · Bundesliga",
                                       leagues: defaultLeagues(team: "soccer/ger.1", nat: false)))
                out.append(SportFollow(kind: "nat", ref: "481", name: "Deutschland", sport: "fb", emoji: "🇩🇪", sub: "Fußball · Nationalmannschaft",
                                       leagues: natLeagues))
                out.append(league("soccer/uefa.champions"))
                out.append(league("soccer/ger.dfb_pokal"))
                out.append(league("soccer/uefa.europa", mode: "de"))
                out.append(league("soccer/uefa.europa.conf", mode: "de"))
            }
            if c["tn"]?.bool ?? true {
                out.append(league("tennis/atp", mode: "de"))
                out.append(league("tennis/wta", mode: "de"))
            }
            return out
        }
        let known = ["132": "FC Bayern", "481": "Deutschland"]
        var out: [SportFollow] = []
        func addFav(_ f: SportFollow) {
            if let i = out.firstIndex(where: { $0.uid == f.uid }) {
                out[i].leagues += f.leagues.filter { !out[i].leagues.contains($0) }
            } else { out.append(f) }
        }
        for j in list {
            guard let o = j.object, let id = o["id"]?.string else { continue }
            let lg = id == "del" ? "hw/del" : id
            let mode = o["mode"]?.string ?? "all"
            let sp = sport(of: lg)
            if mode != "fav" || sp == "f1" { out.append(league(lg, mode: mode == "de" ? "de" : "all")) }
            let nat = natLeagues.contains(lg)
            let kind = sp == "f1" ? "driver" : sp == "tn" ? "player" : nat ? "nat" : "team"
            let sub = (sportName[sp] ?? "") + " · " + (nat ? "Nationalmannschaft" : leagueName(lg))
            for f in (o["fav"]?.array ?? []).compactMap(\.string) {
                addFav(SportFollow(kind: kind, ref: f, name: known[f] ?? "", sport: sp, emoji: emoji[sp] ?? "🏆", sub: sub, leagues: [lg]))
            }
            for n in (o["names"]?.array ?? []).compactMap(\.string) {
                let ref = kind == "nat" && n == "Deutschland" ? "481" : n
                addFav(SportFollow(kind: kind, ref: ref, name: n, sport: sp, emoji: kind == "nat" && n == "Deutschland" ? "🇩🇪" : (emoji[sp] ?? "🏆"),
                                   sub: sub, leagues: [lg]))
            }
        }
        return out
    }

    // MARK: Filtern

    /// Soll das Spiel gezeigt werden? Ligen: alle (bzw. deutsche) Spiele; sonst nur mit Favorit
    static func shows(_ m: Match, _ f: [SportFollow]) -> Bool {
        let L = m.L ?? ""
        if m.isRace { return f.contains { $0.leagues.contains(L) } }
        return f.contains { x in
            guard x.leagues.contains(L) else { return false }
            if x.isLeague {
                guard x.mode == "de" else { return true }
                return m.sport == "tn" ? (m.a.c == "GER" || m.b.c == "GER" || m.late == true) : m.de == true
            }
            return x.matches(m.a) || x.matches(m.b)
        }
    }

    static func filter(_ all: [Match], _ f: [SportFollow]) -> [Match] { all.filter { shows($0, f) } }

    /// Favorit = Verein, Team, Sportler oder Land, dem man folgt (ganze Ligen zählen nicht)
    static func isFav(_ s: Match.Side, in m: Match, _ f: [SportFollow]) -> Bool {
        let L = m.L ?? ""
        return f.contains { !$0.isLeague && $0.leagues.contains(L) && $0.matches(s) }
    }

    static func favDriver(_ id: String?, _ f: [SportFollow]) -> Bool {
        guard let id = id else { return false }
        return f.contains { $0.kind == "driver" && $0.ref == id }
    }

    static func isFav(_ m: Match, _ f: [SportFollow]) -> Bool {
        if m.isRace { return (m.field ?? []).contains { favDriver($0.id, f) } }
        return isFav(m.a, in: m, f) || isFav(m.b, in: m, f)
    }

    /// Überschrift, unter der ein Spiel steht: „Live“, der Tag („Heute“, „Morgen“, „Montag, 24.11.“) oder „Ergebnisse“
    static func group(_ m: Match) -> String {
        if m.isLive { return "Live" }
        if m.state == "pre" { return Fmt.dayLabel(m.start) }
        return "Ergebnisse"
    }

    /// Startseite: Live zuerst, dann Favoriten, dann der Rest; Ergebnisse höchstens 20 Std. alt
    static func pick(_ all: [Match], _ f: [SportFollow]) -> [Match] {
        let now = Date()
        let order = ["in": 0, "pre": 1, "post": 2]
        return all.filter { $0.state != "post" || now.timeIntervalSince($0.start) < 20 * 3600 }
            .sorted { a, b in
                let oa = order[a.state] ?? 3, ob = order[b.state] ?? 3
                if oa != ob { return oa < ob }
                let fa = isFav(a, f), fb = isFav(b, f)
                if fa != fb && a.state != "pre" { return fa }
                return a.state == "post" ? a.start > b.start : a.start < b.start
            }
    }
}

struct SportGlance: View {
    let follows: [SportFollow]
    let size: BucketSize
    @ObservedObject private var feed = FeedService.shared
    @Environment(\.glanceSpace) private var space

    private var leagues: [String] { SportBucket.leagues(follows) }
    private var key: String { FeedService.key(leagues) }

    var body: some View {
        content.refreshing(id: key, every: { FeedService.shared.sportInterval(key) }) {
            await FeedService.shared.loadSport(leagues: leagues)
        }
    }

    @ViewBuilder private var content: some View {
        if follows.isEmpty {
            Text("Folge Vereinen, Sportlern oder Ligen – über den Regler oben rechts").foregroundColor(Theme.secondary)
        } else if let f = feed.sportFeeds[key] {
            let list = SportBucket.pick(SportBucket.filter(f.matches, follows), follows)
            if list.isEmpty {
                Text("Gerade keine Spiele").foregroundColor(Theme.secondary)
            } else {
                // Nach Tagen geordnet: Überschrift kostet extra Platz (wie bei den Terminen)
                let pages = Pages.split(list, height: space.height) { m, first, prev in
                    54 + ((first || prev.map { SportBucket.group($0) != SportBucket.group(m) } ?? true) ? 20 : 0)
                }
                GlancePager(pages: pages) { page in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(page.enumerated()), id: \.element.id) { i, m in
                            if i == 0 || SportBucket.group(page[i - 1]) != SportBucket.group(m) {
                                Text(SportBucket.group(m).uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(m.isLive ? .red : Theme.secondary)
                                    .frame(height: 20, alignment: .bottomLeading)
                            } else {
                                Divider()
                            }
                            // Jedes Spiel einzeln antippbar
                            NavigationLink(destination: MatchDetailView(match: m, follows: follows)) {
                                HStack(spacing: 6) {
                                    MatchRow(match: m, compact: true, follows: follows, timeOnly: true)
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
    var follows: [SportFollow] = []
    /// Steht der Tag schon in der Überschrift, reicht die Uhrzeit
    var timeOnly = false

    private var status: some View {
        Group {
            if match.isLive {
                Text(match.sport == "tn" ? "LIVE" : match.detailDE)
                    .font(.caption.weight(.bold).monospacedDigit()).foregroundColor(.red)
            } else if match.state == "pre" {
                Text(timeOnly ? Fmt.hhmm(match.start) : Fmt.when(match.start))
                    .font((timeOnly ? Font.subheadline : Font.caption).monospacedDigit()).foregroundColor(Theme.secondary)
            } else {
                Text(match.detail.isEmpty ? "Ende" : match.detailDE).font(.caption).foregroundColor(Theme.secondary)
            }
        }
        .lineLimit(2).multilineTextAlignment(.leading)
        .frame(width: compact ? 58 : 70, alignment: .leading)
    }

    private func line(_ s: Match.Side, _ o: Match.Side) -> some View {
        let fav = SportBucket.isFav(s, in: match, follows)
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
                let favs = field.filter { SportBucket.favDriver($0.id, follows) }
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
    let follows: [SportFollow]
    @State private var only = "alle"
    /// 0 Spiele · 1 Tabellen (nur wenn man Fußball-Wettbewerben folgt)
    @State private var mode = 0
    @ObservedObject private var feed = FeedService.shared

    private var tableLeagues: [String] { SportBucket.tableLeagues(follows) }

    private var leagues: [String] { SportBucket.leagues(follows) }
    private var key: String { FeedService.key(leagues) }
    /// Sportarten in der Auswahl, in fester Reihenfolge
    private var sports: [String] {
        let have = Set(follows.map(\.sport))
        return SportBucket.order.filter(have.contains)
    }

    private struct Day: Identifiable { let id: Date; let matches: [Match] }

    var body: some View {
        let all = SportBucket.filter(feed.sportFeeds[key]?.matches ?? [], follows).filter { only == "alle" || $0.sport == only }
        let pre = all.filter { $0.state == "pre" }.sorted { $0.start < $1.start }
        let byDay = Dictionary(grouping: pre) { Calendar.current.startOfDay(for: $0.start) }
        let days = byDay.keys.sorted().map { Day(id: $0, matches: byDay[$0] ?? []) }
        List {
            if !tableLeagues.isEmpty {
                Picker("", selection: $mode) { Text("Spiele").tag(0); Text("Tabellen").tag(1) }
                    .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if mode == 1 && !tableLeagues.isEmpty {
                SportTablesContent(leagues: tableLeagues, follows: follows)
            } else {
                games(all: all, pre: pre, days: days)
            }
        }
        .listStyle(.insetGrouped)
        .refreshing(id: key, every: { FeedService.shared.sportInterval(key) }) { await FeedService.shared.loadSport(leagues: leagues) }
        // Tabellen nur laden, solange „Tabellen“ offen ist
        .refreshing(id: "tab\(mode):" + tableLeagues.joined(separator: ","),
                    every: { tableLeagues.map { FeedService.shared.tableInterval($0) }.min() ?? 600 }) {
            guard mode == 1 else { return }
            for l in tableLeagues { await FeedService.shared.loadTable(l) }
        }
    }

    @ViewBuilder private func games(all: [Match], pre: [Match], days: [Day]) -> some View {
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
        if follows.isEmpty { Text("Du folgst noch niemandem – oben rechts über den Regler einstellen.").foregroundColor(Theme.secondary) }
        else if feed.sportFeeds[key] == nil { ProgressView() }
        else if all.isEmpty { Text("Gerade keine Spiele").foregroundColor(Theme.secondary) }
        section("Live", all.filter { $0.isLive }.sorted { $0.start < $1.start })
        // Favoriten oben zusätzlich – im Tagesplan darunter stehen sie trotzdem (mit Stern)
        section("Meine Favoriten", pre.filter { SportBucket.isFav($0, follows) })
        // Demnächst: nach Tagen, innerhalb des Tages nach Uhrzeit
        ForEach(days) { d in
            section(days.first?.id == d.id ? "Demnächst · " + Fmt.dayLabel(d.id) : Fmt.dayLabel(d.id), d.matches, timeOnly: true)
        }
        section("Ergebnisse", all.filter { $0.state == "post" }.sorted { $0.start > $1.start })
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

    @ViewBuilder private func section(_ title: String, _ list: [Match], timeOnly: Bool = false) -> some View {
        if !list.isEmpty {
            Section(header: Text(title)) {
                ForEach(list) { m in
                    NavigationLink(destination: MatchDetailView(match: m, follows: follows)) {
                        MatchRow(match: m, follows: follows, timeOnly: timeOnly).padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

// Spielseite (MatchDetailView): Buckets/SportMatch.swift
