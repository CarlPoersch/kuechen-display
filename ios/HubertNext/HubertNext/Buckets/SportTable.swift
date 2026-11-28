import SwiftUI

// ============================================================
// Tabellen (Fußball): eine Ansicht für den Reiter „Tabelle“ in der
// Spielseite und für „Tabellen“ in der Sport-App.
// Daten: Funktion „spiel“ → FeedService.tables (Reihenfolge und Zonen von
// ESPN, nichts selbst berechnet).
// ============================================================

/// Form-Reihe: älteste links, neueste rechts (Server liefert neueste zuerst)
struct FormDots: View {
    let form: [String]
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(form.prefix(5).reversed().enumerated()), id: \.offset) { _, r in
                Text(r)
                    .font(.system(size: size * 0.62, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: size, height: size)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Self.color(r)))
            }
        }
        .accessibilityLabel("Form: " + form.prefix(5).joined(separator: " "))
    }

    static func color(_ r: String) -> Color {
        switch r {
        case "S": return Color(UIColor.systemGreen)
        case "N": return Color(UIColor.systemRed)
        default: return Color(UIColor.systemGray2)
        }
    }
}

/// Eine Tabelle (bzw. Gruppe) als Abschnitt in einer Liste
struct TableSection: View {
    let table: LeagueTable
    let group: LeagueTable.Group
    var title: String?
    /// Teams des Spiels – farbig hinterlegt
    var highlight: Set<String> = []
    /// Lieblingsteams – fett mit Stern
    var favs: Set<String> = []
    var wide = false

    private var zones: [LeagueTable.Zone] {
        let used = Set(group.rows.compactMap(\.z))
        return table.zones.enumerated().filter { used.contains($0.offset) }.map { $0.element }
    }
    private var showForm: Bool { wide && !table.form.isEmpty }

    var body: some View {
        Section(header: title.map { Text($0) }, footer: legend) {
            columns
            ForEach(group.rows) { r in
                row(r).listRowBackground(highlight.contains(r.id) ? Theme.accent.opacity(0.14) : Theme.card)
            }
        }
    }

    private var columns: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 3, height: 1)
            Text("#").frame(width: 22, alignment: .trailing)
            Text("Team")
            Spacer(minLength: 4)
            if wide {
                col("S"); col("U"); col("N")
                col("Tore", width: 50)
            }
            col("Sp."); col("TD", width: 34); col("Pkt.", width: 34)
            if showForm { Text("Form").frame(width: 5 * 16 + 4 * 3, alignment: .leading) }
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(Theme.secondary)
    }

    private func row(_ r: LeagueTable.Row) -> some View {
        let fav = favs.contains(r.id)
        let strong = fav || highlight.contains(r.id)
        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(r.z.flatMap { $0 < table.zones.count ? table.zones[$0].color : nil } ?? .clear)
                .frame(width: 3, height: 22)
            Text("\(r.p)").font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary).frame(width: 22, alignment: .trailing)
            HStack(spacing: 4) {
                Text(r.n).fontWeight(strong ? .semibold : .regular).lineLimit(1)
                if fav { Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow) }
            }
            Spacer(minLength: 4)
            if wide {
                num("\(r.s)"); num("\(r.u)"); num("\(r.nl)")
                Text("\(r.tf):\(r.tg)").font(.subheadline.monospacedDigit()).frame(width: 50, alignment: .trailing)
            }
            num("\(r.sp)")
            num(r.td > 0 ? "+\(r.td)" : "\(r.td)", width: 34)
            Text("\(r.pk)").font(.subheadline.monospacedDigit().weight(.semibold)).frame(width: 34, alignment: .trailing)
            if showForm {
                FormDots(form: table.form[r.id] ?? []).frame(width: 5 * 16 + 4 * 3, alignment: .leading)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 2)
    }

    private func col(_ t: String, width: CGFloat = 26) -> some View {
        Text(t).frame(width: width, alignment: .trailing)
    }

    private func num(_ t: String, width: CGFloat = 26) -> some View {
        Text(t).font(.subheadline.monospacedDigit()).frame(width: width, alignment: .trailing)
    }

    @ViewBuilder private var legend: some View {
        if !zones.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(zones, id: \.self) { z in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5).fill(z.color).frame(width: 10, height: 10)
                        Text(z.t)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

/// „Tabellen“ in der Sport-App: eine Kapsel je gefolgtem Fußball-Wettbewerb mit Tabelle
struct SportTablesContent: View {
    let leagues: [String]
    let follows: [SportFollow]
    @State private var picked: String?
    @ObservedObject private var feed = FeedService.shared
    @Environment(\.horizontalSizeClass) private var hSize

    private var available: [String] { leagues.filter { feed.tables[$0]?.isEmpty == false } }
    private var loading: Bool { leagues.contains { feed.tables[$0] == nil } }
    private var current: String? { picked.flatMap { available.contains($0) ? $0 : nil } ?? available.first }

    var body: some View {
        Group {
            if available.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(available, id: \.self) { chip($0) } }.padding(.vertical, 2)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if let l = current, let t = feed.tables[l] {
                let favs = SportBucket.favTeams(follows)
                // Gruppen mit Lieblingsteams zuerst
                let groups = t.groups.sorted { a, b in
                    let fa = a.rows.contains { favs.contains($0.id) }, fb = b.rows.contains { favs.contains($0.id) }
                    return fa && !fb
                }
                ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                    TableSection(table: t, group: g, title: g.n ?? SportBucket.leagueName(l), favs: favs, wide: hSize == .regular)
                }
            } else if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("Für deine Wettbewerbe gibt es gerade keine Tabelle.").foregroundColor(Theme.secondary)
            }
        }
    }

    private func chip(_ l: String) -> some View {
        let on = l == current
        return Button { withAnimation { picked = l } } label: {
            Text(SportBucket.leagueName(l)).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .foregroundColor(on ? .white : .primary)
                .background(Capsule().fill(on ? Theme.accent : Theme.card))
        }
        .buttonStyle(.plain)
    }
}

extension SportBucket {
    /// Team-IDs, denen man folgt (Vereine und Nationalteams im Fußball)
    static func favTeams(_ f: [SportFollow]) -> Set<String> {
        Set(f.filter { ($0.kind == "team" || $0.kind == "nat") && $0.sport == "fb" }.map(\.ref))
    }
    /// Fußball-Wettbewerbe der Auswahl, für die es Tabellen geben kann (Pokale fallen weg, sobald die Tabelle leer zurückkommt)
    static func tableLeagues(_ f: [SportFollow]) -> [String] {
        leagues(f).filter { $0.hasPrefix("soccer/") }
    }
}
