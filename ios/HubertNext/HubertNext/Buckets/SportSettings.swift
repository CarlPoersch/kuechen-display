import SwiftUI

// ============================================================
// Sport personalisieren – angelehnt an Apple Sports:
//  1. Einstellungen der Karte → „Ligen & Favoriten“
//  2. Oben die eigene Auswahl, darunter alle Sportarten zum Hinzufügen
//  3. Liga antippen → was gezeigt wird + Favoriten mit Stern
// ============================================================

/// Zeile in den Karten-Einstellungen
struct SportSettings: View {
    @Binding var config: [String: JSON]

    private var picks: [SportPick] { SportBucket.picks(config) }

    var body: some View {
        NavigationLink(destination: SportPicker(config: $config)) {
            HStack(spacing: 12) {
                Text(Array(Set(picks.map(\.sport))).sorted().compactMap { SportBucket.emoji[$0] }.prefix(4).joined())
                    .frame(minWidth: 30, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ligen & Favoriten")
                    let favs = picks.reduce(0) { $0 + $1.fav.count + $1.names.count }
                    Text(picks.isEmpty ? "Noch nichts gewählt"
                         : "\(picks.count) \(picks.count == 1 ? "Liga" : "Ligen")" + (favs > 0 ? " · \(favs) \(favs == 1 ? "Favorit" : "Favoriten")" : ""))
                        .font(.caption).foregroundColor(Theme.secondary)
                }
            }
        }
    }
}

/// Auswahl der Ligen (oben: deine, darunter: alle zum Hinzufügen)
struct SportPicker: View {
    @Binding var config: [String: JSON]
    @ObservedObject private var feed = FeedService.shared
    @State private var query = ""

    private var picks: [SportPick] { SportBucket.picks(config) }
    private func save(_ p: [SportPick]) { SportBucket.store(p, in: &config) }

    private func league(_ id: String) -> (sport: SportCatalog, league: SportCatalog.League)? {
        for s in feed.catalog { if let l = s.leagues.first(where: { $0.id == id }) { return (s, l) } }
        return nil
    }

    var body: some View {
        List {
            Section {
                if picks.isEmpty {
                    Text("Füge unten Ligen hinzu, die dich interessieren.").foregroundColor(Theme.secondary)
                }
                ForEach(picks) { p in
                    NavigationLink(destination: LeaguePickView(config: $config, leagueId: p.id)) {
                        HStack(spacing: 12) {
                            Text(SportBucket.emoji[p.sport] ?? "🏆").font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(league(p.id)?.league.name ?? p.id)
                                Text(LeaguePickView.summary(p)).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                .onDelete { idx in var l = picks; l.remove(atOffsets: idx); save(l) }
                .onMove { from, to in var l = picks; l.move(fromOffsets: from, toOffset: to); save(l) }
            } header: { Text("Deine Auswahl") } footer: {
                Text("Antippen: Favoriten wählen und festlegen, ob alle Spiele oder nur die deiner Favoriten erscheinen. Wischen entfernt eine Liga.")
            }

            ForEach(feed.catalog) { sport in
                let rest = sport.leagues.filter { l in !picks.contains { $0.id == l.id } }
                    .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || sport.name.localizedCaseInsensitiveContains(query) }
                if !rest.isEmpty {
                    Section(header: Text(sport.emoji + "  " + sport.name)) {
                        ForEach(rest) { l in
                            Button { withAnimation { add(l) } } label: {
                                HStack {
                                    Text(l.name).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(Theme.accent)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(l.name) hinzufügen")
                        }
                    }
                }
            }
            if feed.catalog.isEmpty {
                Section { HStack { ProgressView(); Text("Lade Sportarten …").foregroundColor(Theme.secondary) } }
            }
            Section {
                EmptyView()
            } footer: {
                Text("Handball, BBL und Radsport folgen, sobald es dafür eine verlässliche Datenquelle gibt. Die DEL kommt aus OpenLigaDB (Ergebnisse kurz nach Spielende), die Formel 1 ohne Live-Positionen.")
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Liga suchen")
        .navigationTitle("Ligen & Favoriten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { EditButton() } }
        .task { await feed.loadCatalog() }
    }

    private func add(_ l: SportCatalog.League) {
        var list = picks
        // Länderspiele: gleich Deutschland als Favorit, damit nicht alle Länder kommen
        if l.kind == "nat" { list.append(SportPick(id: l.id, mode: "fav", names: ["Deutschland"])) }
        else { list.append(SportPick(id: l.id)) }
        save(list)
    }
}

/// Eine Liga: was gezeigt wird + Favoriten
struct LeaguePickView: View {
    @Binding var config: [String: JSON]
    let leagueId: String
    @ObservedObject private var feed = FeedService.shared
    @State private var teams: [TeamRef] = []
    @State private var loading = true
    @State private var query = ""
    @State private var newName = ""

    private var pick: SportPick { SportBucket.picks(config).first { $0.id == leagueId } ?? SportPick(id: leagueId) }
    private var kind: String? { feed.catalog.flatMap(\.leagues).first { $0.id == leagueId }?.kind }
    private var name: String { feed.catalog.flatMap(\.leagues).first { $0.id == leagueId }?.name ?? leagueId }
    private var sport: String { SportBucket.sport(of: leagueId) }

    private func update(_ change: (inout SportPick) -> Void) {
        var list = SportBucket.picks(config)
        guard let i = list.firstIndex(where: { $0.id == leagueId }) else { return }
        change(&list[i])
        SportBucket.store(list, in: &config)
    }

    /// Kurzbeschreibung für die Liste
    static func summary(_ p: SportPick) -> String {
        let n = p.fav.count + p.names.count
        if p.sport == "f1" { return n == 0 ? "Alle Rennen" : "Alle Rennen · \(n) Fahrer markiert" }
        switch p.mode {
        case "fav": return n == 0 ? "Nur Favoriten – noch keine gewählt" : "Nur Favoriten (\(n))"
        case "de": return p.sport == "tn" ? "Deutsche & Endspiele" : "Mit deutschen Vereinen"
        default: return n == 0 ? "Alle Spiele" : "Alle Spiele · \(n) Favoriten"
        }
    }

    private var modes: [(String, String)] {
        if sport == "f1" { return [] }
        var m = [("all", "Alle Spiele"), ("fav", sport == "tn" ? "Nur meine Spieler" : "Nur meine Favoriten")]
        if sport == "tn" { m.insert(("de", "Deutsche & Endspiele"), at: 1) }
        if kind == "intl" { m.insert(("de", "Mit deutschen Vereinen"), at: 1) }
        return m
    }

    private func isFav(_ t: TeamRef) -> Bool { pick.fav.contains(t.id) || pick.names.contains { $0.caseInsensitiveCompare(t.n) == .orderedSame } }

    private func toggle(_ t: TeamRef) {
        update { p in
            if isFav(t) {
                p.fav.removeAll { $0 == t.id }
                p.names.removeAll { $0.caseInsensitiveCompare(t.n) == .orderedSame }
            } else {
                p.fav.append(t.id)
                // Wer einen Favoriten wählt, will meist nur dessen Spiele sehen (bei großen Ligen)
                if p.mode == "all" && p.fav.count == 1 && p.names.isEmpty && sport != "f1" { p.mode = "fav" }
            }
        }
    }

    /// Spieler aus den aktuellen Spielen (Tennis) als Vorschläge
    private var players: [String] {
        let all = feed.sportFeeds.values.flatMap(\.matches).filter { $0.L == leagueId }
        let names = all.flatMap { [$0.a.full ?? $0.a.n, $0.b.full ?? $0.b.n] }
        return Array(Set(names)).filter { n in !pick.names.contains { $0.caseInsensitiveCompare(n) == .orderedSame } }.sorted()
    }

    var body: some View {
        List {
            if !modes.isEmpty {
                Section(header: Text("Auf der Karte zeigen")) {
                    ForEach(modes, id: \.0) { m in
                        Button { withAnimation { update { $0.mode = m.0 } } } label: {
                            HStack {
                                Text(m.1).foregroundColor(.primary)
                                Spacer()
                                if pick.mode == m.0 { Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundColor(Theme.accent) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if sport == "tn" {
                Section {
                    ForEach(pick.names, id: \.self) { n in
                        HStack {
                            Image(systemName: "star.fill").foregroundColor(.yellow)
                            Text(n)
                            Spacer()
                            Button { update { $0.names.removeAll { $0 == n } } } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(n) entfernen")
                        }
                    }
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent)
                        TextField("Spieler, z. B. Zverev", text: $newName)
                            .submitLabel(.done).onSubmit { addName(newName) }
                    }
                    ForEach(players.filter { newName.isEmpty || $0.localizedCaseInsensitiveContains(newName) }.prefix(12), id: \.self) { n in
                        Button { addName(n) } label: {
                            HStack { Text(n).foregroundColor(.primary); Spacer(); Image(systemName: "star").foregroundColor(Theme.accent) }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: { Text("Meine Spieler") } footer: {
                    Text("Vorschläge sind die Spieler, die diese Woche spielen. Ein Teil des Namens reicht.")
                }
            } else {
                Section {
                    if loading { HStack { ProgressView(); Text("Lädt …").foregroundColor(Theme.secondary) } }
                    let list = teams.filter { query.isEmpty || $0.n.localizedCaseInsensitiveContains(query) }
                        .sorted { (isFav($0) ? 0 : 1, $0.n) < (isFav($1) ? 0 : 1, $1.n) }
                    ForEach(list) { t in
                        Button { withAnimation { toggle(t) } } label: {
                            HStack {
                                Text(t.n).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: isFav(t) ? "star.fill" : "star")
                                    .foregroundColor(isFav(t) ? .yellow : Color(UIColor.tertiaryLabel))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(t.n + (isFav(t) ? ", Favorit" : ""))
                    }
                    if !loading && teams.isEmpty { Text("Gerade keine Teams verfügbar").foregroundColor(Theme.secondary) }
                } header: { Text(sport == "f1" ? "Meine Fahrer" : "Meine Vereine") } footer: {
                    Text(sport == "f1" ? "Markierte Fahrer siehst du im Ergebnis immer, auch außerhalb der Top 3."
                         : "Stern = Favorit. Favoriten stehen auf der Karte oben und sind fett markiert.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .modifier(SearchIf(on: sport != "tn", text: $query, prompt: sport == "f1" ? "Fahrer suchen" : "Verein suchen"))
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if feed.catalog.isEmpty { await feed.loadCatalog() }
            if sport == "tn" { await feed.loadSport(leagues: [leagueId]) }
            else { teams = await feed.teams(leagueId) }
            loading = false
        }
    }

    private func addName(_ raw: String) {
        let n = raw.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !pick.names.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) else { newName = ""; return }
        update { p in
            p.names.append(n)
            if p.mode == "all" && p.names.count == 1 && p.fav.isEmpty { p.mode = "fav" }
        }
        newName = ""
    }
}

/// Suchfeld nur, wo es Sinn ergibt (bei Tennis gibt es eine eigene Eingabe)
private struct SearchIf: ViewModifier {
    let on: Bool
    @Binding var text: String
    let prompt: String
    func body(content: Content) -> some View {
        if on { content.searchable(text: $text, prompt: prompt) } else { content }
    }
}
