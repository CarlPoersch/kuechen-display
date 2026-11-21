import SwiftUI

// ============================================================
// Sport personalisieren – wie die Haltestellensuche:
//  1. Einstellungen der Karte → „Ich folge“
//  2. Oben suchen: Verein, Sportler, Liga oder Land → offizielle Treffer
//     mit Stern zum Folgen
//  3. Darunter: wem man folgt (antippen = Wettbewerbe wählen) und Stöbern
// ============================================================

/// Zeile in den Karten-Einstellungen
struct SportSettings: View {
    @Binding var config: [String: JSON]

    private var follows: [SportFollow] { SportBucket.follows(config) }

    var body: some View {
        NavigationLink(destination: SportFollowView(config: $config)) {
            HStack(spacing: 12) {
                Text(SportBucket.order.filter { s in follows.contains { $0.sport == s } }.compactMap { SportBucket.emoji[$0] }.prefix(4).joined())
                    .frame(minWidth: 30, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ich folge")
                    Text(summary).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                }
            }
        }
    }

    private var summary: String {
        if follows.isEmpty { return "Vereine, Sportler und Ligen suchen" }
        let names = follows.map { $0.name.isEmpty ? SportBucket.leagueName($0.ref) : $0.name }
        return names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " +\(names.count - 3)" : "")
    }
}

/// Eine Zeile: Symbol im Kreis, Name, Unterzeile, rechts optional ein Stern
struct FollowRow: View {
    let emoji: String
    let name: String
    let sub: String
    var on: Bool? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 20))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).foregroundColor(.primary).lineLimit(1)
                if !sub.isEmpty { Text(sub).font(.caption).foregroundColor(Theme.secondary).lineLimit(1) }
            }
            Spacer(minLength: 8)
            if let on = on {
                Image(systemName: on ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundColor(on ? .yellow : Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(on == true ? "Folge ich" : "")
    }
}

/// Suchen, folgen, verwalten
struct SportFollowView: View {
    @Binding var config: [String: JSON]
    @ObservedObject private var feed = FeedService.shared
    @State private var query = ""
    @State private var hits: [SportHit] = []
    @State private var searching = false
    @State private var failed = false

    private var follows: [SportFollow] { SportBucket.follows(config) }
    private func save(_ f: [SportFollow]) { SportBucket.store(f, in: &config) }
    private var searchActive: Bool { query.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        List {
            if searchActive {
                results
            } else {
                following
                browse
                Section {
                    EmptyView()
                } footer: {
                    Text("Quellen: ESPN (Fußball, Tennis, NBA, NHL, NFL, MLB), HockeyWeb (Eishockey in Deutschland von DEL bis Bayernliga) und die Formel-1-Datenbank Jolpica. Handball, BBL und Radsport folgen, sobald es dafür eine verlässliche Quelle gibt.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Verein, Sportler, Liga oder Land")
        .disableAutocorrection(true)
        .navigationTitle("Ich folge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !searchActive && !follows.isEmpty { EditButton() }
            }
        }
        .task(id: query) { await search() }
        .task {
            if feed.catalog.isEmpty { await feed.loadCatalog() }
            await resolveNames()
        }
    }

    // MARK: Suche

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { hits = []; searching = false; failed = false; return }
        searching = true
        try? await Task.sleep(nanoseconds: 350_000_000)   // erst nach einer kurzen Tipp-Pause
        guard !Task.isCancelled else { return }
        do {
            let r = try await feed.searchSport(q)
            guard !Task.isCancelled else { return }
            hits = r; failed = false
        } catch {
            guard !Task.isCancelled else { return }
            hits = []; failed = true
        }
        searching = false
    }

    private func isFollowed(_ h: SportHit) -> Bool { follows.contains { $0.uid == h.uid } }

    private func toggle(_ h: SportHit) {
        var list = follows
        if let i = list.firstIndex(where: { $0.uid == h.uid }) { list.remove(at: i) } else { list.append(SportFollow(h)) }
        save(list)
    }

    @ViewBuilder private var results: some View {
        Section {
            if searching && hits.isEmpty {
                HStack(spacing: 10) { ProgressView(); Text("Suche …").foregroundColor(Theme.secondary) }
            } else if failed {
                Text("Die Suche klappt gerade nicht – bitte gleich nochmal.").foregroundColor(Theme.secondary)
            } else if hits.isEmpty {
                Text("Nichts gefunden. Probier einen anderen Namen, z. B. „Selb“, „Zverev“ oder „Bundesliga“.").foregroundColor(Theme.secondary)
            }
            ForEach(hits, id: \.uid) { h in
                Button { withAnimation { toggle(h) } } label: {
                    FollowRow(emoji: h.emoji, name: h.name, sub: h.kind == "league" && h.sport == "f1" ? "Formel 1 · alle Rennen" : h.sub,
                              on: isFollowed(h))
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Treffer")
        } footer: {
            if !hits.isEmpty { Text("Stern antippen zum Folgen. Namen und Zuordnung kommen direkt aus den offiziellen Spielplänen.") }
        }
    }

    // MARK: Ich folge

    @ViewBuilder private var following: some View {
        Section {
            if follows.isEmpty {
                Text("Noch nichts – such oben nach deinem Verein, deinem Lieblingsspieler oder einer Liga.")
                    .foregroundColor(Theme.secondary)
            }
            ForEach(follows, id: \.uid) { f in
                NavigationLink(destination: FollowEditView(config: $config, uid: f.uid)) {
                    FollowRow(emoji: f.emoji, name: f.name.isEmpty ? "Lädt …" : f.name, sub: FollowEditView.summary(f))
                }
            }
            .onDelete { idx in var l = follows; l.remove(atOffsets: idx); save(l) }
            .onMove { from, to in var l = follows; l.move(fromOffsets: from, toOffset: to); save(l) }
        } header: {
            Text("Ich folge")
        } footer: {
            if !follows.isEmpty { Text("Antippen: in welchen Wettbewerben Hubert die Spiele zeigt. Wischen entfernt.") }
        }
    }

    @ViewBuilder private var browse: some View {
        Section(header: Text("Stöbern")) {
            ForEach(feed.catalog) { s in
                NavigationLink(destination: BrowseSportView(config: $config, sport: s)) {
                    FollowRow(emoji: s.emoji, name: s.name, sub: s.leagues.prefix(3).map(\.name).joined(separator: ", "))
                }
            }
            if feed.catalog.isEmpty {
                HStack(spacing: 10) { ProgressView(); Text("Lade Sportarten …").foregroundColor(Theme.secondary) }
            }
        }
    }

    /// Ältere Karten kennen nur die Team-ID – den Namen einmal nachladen
    private func resolveNames() async {
        var names: [String: String] = [:]
        for f in follows where f.name.isEmpty {
            for lg in f.leagues {
                if let t = await feed.teams(lg).first(where: { $0.id == f.ref }) { names[f.uid] = t.n; break }
            }
        }
        guard !names.isEmpty else { return }
        var list = follows
        for i in list.indices { if list[i].name.isEmpty, let n = names[list[i].uid] { list[i].name = n } }
        save(list)
    }
}

/// Ein Favorit: Wettbewerbe bzw. was gezeigt wird
struct FollowEditView: View {
    @Binding var config: [String: JSON]
    let uid: String
    @ObservedObject private var feed = FeedService.shared
    @Environment(\.dismiss) private var dismiss

    private var follow: SportFollow? { SportBucket.follows(config).first { $0.uid == uid } }

    private func update(_ change: (inout SportFollow) -> Void) {
        var list = SportBucket.follows(config)
        guard let i = list.firstIndex(where: { $0.uid == uid }) else { return }
        change(&list[i])
        SportBucket.store(list, in: &config)
    }

    /// Kurzbeschreibung für die Liste
    static func summary(_ f: SportFollow) -> String {
        let sport = SportBucket.sportName[f.sport] ?? ""
        switch f.kind {
        case "league":
            if f.sport == "f1" { return "Alle Rennen" }
            if f.mode == "de" { return f.sport == "tn" ? "Deutsche & Endspiele" : "Nur Spiele deutscher Vereine" }
            return sport + " · alle Spiele"
        case "driver": return "Formel 1 · Fahrer"
        case "country": return f.sub
        default:
            let names = f.leagues.map { SportBucket.leagueName($0) }
            if f.kind == "nat" && f.sport == "fb" { return "Fußball · alle Länderspiele" }
            return sport + " · " + names.prefix(2).joined(separator: ", ") + (names.count > 2 ? " +\(names.count - 2)" : "")
        }
    }

    /// Wettbewerbe, aus denen man wählen kann
    private func candidates(_ f: SportFollow) -> [SportCatalog.League] {
        let all = feed.catalog.first { $0.id == f.sport }?.leagues ?? []
        if f.sport == "fb" { return all.filter { f.kind == "nat" ? $0.kind == "nat" : $0.kind != "nat" } }
        return all
    }

    private var modes: [(String, String)] {
        guard let f = follow, f.isLeague, f.sport != "f1" else { return [] }
        if f.sport == "tn" { return [("all", "Alle Spiele"), ("de", "Nur Deutsche & Endspiele")] }
        if SportBucket.intlLeagues.contains(f.ref) { return [("all", "Alle Spiele"), ("de", "Nur Spiele deutscher Vereine")] }
        return []
    }

    var body: some View {
        List {
            if let f = follow {
                Section {
                    VStack(spacing: 6) {
                        Text(f.emoji).font(.system(size: 44))
                        Text(f.name).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                        if !f.sub.isEmpty { Text(f.sub).font(.subheadline).foregroundColor(Theme.secondary).multilineTextAlignment(.center) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }

                if !modes.isEmpty {
                    Section(header: Text("Auf der Karte zeigen")) {
                        ForEach(modes, id: \.0) { m in
                            check(m.1, on: f.mode == m.0) { update { $0.mode = m.0 } }
                        }
                    }
                }

                if !f.isLeague && f.kind != "driver" {
                    let list = candidates(f)
                    if list.count > 1 {
                        Section {
                            ForEach(list) { l in
                                let on = f.leagues.contains(l.id)
                                check(l.name, on: on) {
                                    update { x in
                                        if on { if x.leagues.count > 1 { x.leagues.removeAll { $0 == l.id } } }
                                        else { x.leagues.append(l.id) }
                                    }
                                }
                            }
                        } header: {
                            Text("Wettbewerbe")
                        } footer: {
                            Text(f.kind == "player" || f.kind == "country"
                                 ? "Hubert zeigt die Matches in den markierten Touren."
                                 : "Hubert zeigt die Spiele in allen markierten Wettbewerben – auch wenn der Verein dort gerade nicht spielt, schadet ein Haken nicht.")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        let list = SportBucket.follows(config).filter { $0.uid != uid }
                        SportBucket.store(list, in: &config)
                        dismiss()
                    } label: {
                        Text("Nicht mehr folgen").frame(maxWidth: .infinity)
                    }
                }
            } else {
                Text("Nicht mehr in deiner Auswahl").foregroundColor(Theme.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(follow?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { if feed.catalog.isEmpty { await feed.loadCatalog() } }
    }

    private func check(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation { action() } } label: {
            HStack {
                Text(title).foregroundColor(.primary)
                Spacer()
                if on { Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundColor(Theme.accent) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Stöbern: Ligen einer Sportart
struct BrowseSportView: View {
    @Binding var config: [String: JSON]
    let sport: SportCatalog

    var body: some View {
        List {
            Section {
                ForEach(sport.leagues) { l in
                    NavigationLink(destination: BrowseLeagueView(config: $config, sport: sport, league: l)) {
                        HStack {
                            Text(l.name)
                            Spacer()
                            if SportBucket.follows(config).contains(where: { $0.leagues.contains(l.id) }) {
                                Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow)
                            }
                        }
                    }
                }
            } footer: {
                Text("Stern = du folgst dort einem Verein, Sportler oder der ganzen Liga.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(sport.emoji + " " + sport.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Stöbern: eine Liga – ganz folgen oder einzelne Vereine/Fahrer
struct BrowseLeagueView: View {
    @Binding var config: [String: JSON]
    let sport: SportCatalog
    let league: SportCatalog.League
    @ObservedObject private var feed = FeedService.shared
    @State private var teams: [TeamRef] = []
    @State private var loading = true
    @State private var query = ""

    private var follows: [SportFollow] { SportBucket.follows(config) }
    private func save(_ f: [SportFollow]) { SportBucket.store(f, in: &config) }
    private var isNat: Bool { league.kind == "nat" }
    private var itemKind: String { sport.id == "f1" ? "driver" : isNat ? "nat" : "team" }

    private var leagueFollow: SportFollow { SportBucket.league(league.id, mode: league.kind == "intl" ? "de" : "all") }

    private func follow(_ t: TeamRef) -> SportFollow {
        SportFollow(kind: itemKind, ref: t.id, name: t.n, sport: sport.id,
                    emoji: sport.emoji, sub: sport.id == "f1" ? "Formel 1 · Fahrer" : isNat ? sport.name + " · Nationalmannschaft" : sport.name + " · " + league.name,
                    leagues: sport.id == "f1" ? ["f1"] : SportBucket.defaultLeagues(team: league.id, nat: isNat))
    }

    private func toggle(_ f: SportFollow) {
        var list = follows
        if let i = list.firstIndex(where: { $0.uid == f.uid }) { list.remove(at: i) } else { list.append(f) }
        save(list)
    }

    private func on(_ f: SportFollow) -> Bool { follows.contains { $0.uid == f.uid } }

    var body: some View {
        List {
            Section {
                Button { withAnimation { toggle(leagueFollow) } } label: {
                    FollowRow(emoji: sport.emoji, name: sport.id == "f1" ? "Alle Rennen" : "Ganze Liga folgen",
                              sub: league.kind == "intl" ? "Erst nur Spiele deutscher Vereine – änderbar" : "Alle Spiele auf der Karte",
                              on: on(leagueFollow))
                }
                .buttonStyle(.plain)
            }

            if sport.id == "tn" {
                Section {
                    Text("Spieler findest du über die Suche – einfach den Namen eingeben, z. B. „Zverev“. Auch „Deutschland“ geht: dann siehst du alle deutschen Spieler.")
                        .foregroundColor(Theme.secondary)
                }
            } else {
                Section {
                    if loading { HStack(spacing: 10) { ProgressView(); Text("Lädt …").foregroundColor(Theme.secondary) } }
                    let list = teams.filter { query.isEmpty || $0.n.localizedCaseInsensitiveContains(query) }
                    ForEach(list) { t in
                        let f = follow(t)
                        Button { withAnimation { toggle(f) } } label: {
                            FollowRow(emoji: sport.emoji, name: t.n, sub: "", on: on(f))
                        }
                        .buttonStyle(.plain)
                    }
                    if !loading && teams.isEmpty { Text("Gerade keine Teams verfügbar").foregroundColor(Theme.secondary) }
                } header: {
                    Text(sport.id == "f1" ? "Fahrer" : isNat ? "Länder" : "Vereine")
                } footer: {
                    Text(sport.id == "f1" ? "Markierte Fahrer siehst du im Ergebnis immer, auch außerhalb der Top 3."
                         : "Stern = du folgst. Hubert zeigt dann deren Spiele – bei Fußballvereinen auch Pokal und Europapokal.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .modifier(SearchIf(on: sport.id != "tn", text: $query, prompt: sport.id == "f1" ? "Fahrer suchen" : "In der Liga suchen"))
        .navigationTitle(league.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if sport.id != "tn" { teams = await feed.teams(league.id) }
            loading = false
        }
    }
}

/// Suchfeld nur, wo es Sinn ergibt
private struct SearchIf: ViewModifier {
    let on: Bool
    @Binding var text: String
    let prompt: String
    func body(content: Content) -> some View {
        if on { content.searchable(text: $text, prompt: prompt) } else { content }
    }
}
