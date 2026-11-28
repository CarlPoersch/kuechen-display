import SwiftUI

// ============================================================
// Aufstellung als Spielfeld (Fußball): beide Teams auf einem Feld,
// Heim unten, Gast oben. Spieler werden nach ihrer Position (ESPN-Kürzel
// wie "CD-L", "AM-R", "F") in Reihen gestellt; die Formation sagt, wie
// viele Spieler in welcher Reihe stehen. Passt das nicht zusammen,
// gibt `PitchLayout.lines` nil zurück und die Spielseite zeigt die Liste.
// Design: docs/specs/2026-11-28-sport-spielseite-design.md
// ============================================================

enum PitchLayout {
    typealias Player = MatchDetail.Player

    /// Tiefe: 0 Torwart · 1 Abwehr · 2 defensives Mittelfeld · 3 Mittelfeld · 4 offensives Mittelfeld/Flügel · 5 Sturm
    static func depth(_ raw: String) -> Double? {
        let p = raw.uppercased()
        let known: [String: Double] = [
            "G": 0, "GK": 0,
            "LB": 1, "RB": 1, "CB": 1, "CD": 1, "CD-L": 1, "CD-R": 1, "D": 1, "D-L": 1, "D-R": 1,
            "LWB": 1.2, "RWB": 1.2, "WB": 1.2, "SW": 1.5,
            "DM": 2, "DM-L": 2, "DM-R": 2, "CDM": 2,
            "M": 3, "CM": 3, "CM-L": 3, "CM-R": 3, "LM": 3, "RM": 3,
            "AM": 4, "AM-L": 4, "AM-R": 4, "CAM": 4, "LW": 4, "RW": 4,
            "F": 5, "CF": 5, "CF-L": 5, "CF-R": 5, "ST": 5, "S": 5, "FW": 5, "LF": 5, "RF": 5,
        ]
        if let d = known[p] { return d }
        // Unbekannte Kürzel grob einordnen
        if p.hasPrefix("G") { return 0 }
        if p.hasPrefix("DM") { return 2 }
        if p.hasPrefix("AM") || p.hasSuffix("W") { return 4 }
        if p.hasPrefix("CD") || p.hasSuffix("B") { return 1 }
        if p.hasPrefix("CF") || p.hasPrefix("F") { return 5 }
        if p.contains("M") { return 3 }
        return nil
    }

    /// Seite aus Sicht des Teams: -2 außen links (LB, LM, LW), -1 halblinks (CD-L, AM-L), 0 Mitte, 1 halbrechts, 2 außen rechts
    static func side(_ raw: String) -> Double {
        let p = raw.uppercased()
        if p.hasSuffix("-L") { return -1 }
        if p.hasSuffix("-R") { return 1 }
        if p.count >= 2 && p.hasPrefix("L") { return -2 }
        if p.count >= 2 && p.hasPrefix("R") { return 2 }
        return 0
    }

    /// Reihen von hinten nach vorn (erste Reihe = Torwart), jede Reihe von links nach rechts aus Sicht des Teams.
    static func lines(_ l: MatchDetail.Lineup) -> [[Player]]? {
        let xi = l.xi
        guard xi.count == 11 else { return nil }
        var ranked: [(p: Player, d: Double)] = []
        for p in xi { guard let d = depth(p.pos) else { return nil }; ranked.append((p, d)) }
        // Stabil sortieren: Tiefe, dann Platz in der Formation, dann Reihenfolge von ESPN
        let order = Array(ranked.indices).sorted { i, j in
            let a = ranked[i], b = ranked[j]
            if a.d != b.d { return a.d < b.d }
            let fa = a.p.fp ?? 0, fb = b.p.fp ?? 0
            if fa != fb { return fa < fb }
            return i < j
        }
        ranked = order.map { ranked[$0] }
        guard ranked.filter({ $0.d == 0 }).count == 1, ranked[0].d == 0 else { return nil }
        let field = Array(ranked.dropFirst())

        var counts = l.form.split(separator: "-").compactMap { Int($0) }
        if counts.isEmpty || counts.reduce(0, +) != 10 {
            guard l.form.isEmpty else { return nil }
            // Ohne Formation: Reihen nach Tiefe bilden
            var groups: [Int] = []
            var last: Double?
            for x in field { if x.d == last { groups[groups.count - 1] += 1 } else { groups.append(1); last = x.d } }
            counts = groups
        }
        var out: [[Player]] = [[ranked[0].p]]
        var i = 0
        for c in counts {
            let row: [Player] = field[i..<(i + c)].sorted { x, y in
                let sx = side(x.p.pos), sy = side(y.p.pos)
                if sx != sy { return sx < sy }
                return (x.p.fp ?? 0) < (y.p.fp ?? 0)
            }.map { $0.p }
            out.append(row)
            i += c
        }
        return out
    }
}

/// Spielfeld mit beiden Aufstellungen
struct PitchView: View {
    let home: [[MatchDetail.Player]]
    let away: [[MatchDetail.Player]]
    let homeName: String
    let awayName: String
    let homeForm: String
    let awayForm: String

    private static let grass = Color(red: 0.20, green: 0.52, blue: 0.29)
    private static let grassDark = Color(red: 0.18, green: 0.48, blue: 0.27)

    var body: some View {
        VStack(spacing: 8) {
            caption(awayName, awayForm)
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                let slot = w / 5.4
                ZStack {
                    stripes
                    PitchLines().stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                    // Gast oben (spielt nach unten: seine linke Seite ist rechts im Bild)
                    ForEach(spots(away, home: false), id: \.key) { s in
                        PitchPlayer(p: s.p, home: false, compact: w < 420)
                            .frame(width: slot)
                            .position(x: s.x * w, y: s.y * h + 13)
                    }
                    ForEach(spots(home, home: true), id: \.key) { s in
                        PitchPlayer(p: s.p, home: true, compact: w < 420)
                            .frame(width: slot)
                            .position(x: s.x * w, y: s.y * h + 13)
                    }
                }
            }
            .aspectRatio(1 / 1.55, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            caption(homeName, homeForm)
        }
        .padding(.vertical, 6)
    }

    private func caption(_ name: String, _ form: String) -> some View {
        HStack {
            Text(name).font(.subheadline.weight(.semibold)).lineLimit(1)
            Spacer()
            if !form.isEmpty { Text(form).font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary) }
        }
    }

    private var stripes: some View {
        VStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { i in (i % 2 == 0 ? Self.grass : Self.grassDark) }
        }
    }

    private struct Spot { let key: String; let p: MatchDetail.Player; let x: CGFloat; let y: CGFloat }

    /// Mittelpunkt des Spieler-Kreises in Anteilen des Felds (0…1)
    private func spots(_ lines: [[MatchDetail.Player]], home: Bool) -> [Spot] {
        var out: [Spot] = []
        let n = lines.count - 1   // Reihen ohne Torwart
        for (li, row) in lines.enumerated() {
            // t = Abstand vom eigenen Tor (Anteil der Feldlänge)
            let t: CGFloat
            if li == 0 { t = home ? 0.075 : 0.045 }
            else {
                let lo: CGFloat = home ? 0.17 : 0.14, hi: CGFloat = home ? 0.45 : 0.42
                t = n <= 1 ? (lo + hi) / 2 : lo + (hi - lo) * CGFloat(li - 1) / CGFloat(n - 1)
            }
            for (i, p) in row.enumerated() {
                var x = CGFloat(i + 1) / CGFloat(row.count + 1)
                if !home { x = 1 - x }
                out.append(Spot(key: (home ? "h" : "a") + (p.id ?? p.nr + p.n), p: p, x: x, y: home ? 1 - t : t))
            }
        }
        return out
    }
}

/// Linien: Rand, Mittellinie, Mittelkreis, Strafräume, Torräume
private struct PitchLines: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let inset: CGFloat = 6
        let f = r.insetBy(dx: inset, dy: inset)
        p.addRect(f)
        p.move(to: CGPoint(x: f.minX, y: r.midY)); p.addLine(to: CGPoint(x: f.maxX, y: r.midY))
        let cr = w * 0.13
        p.addEllipse(in: CGRect(x: r.midX - cr, y: r.midY - cr, width: cr * 2, height: cr * 2))
        // Strafraum 59 %, Torraum 27 % der Breite (wie im echten Feld 40,3 m bzw. 18,3 m von 68 m)
        for top in [true, false] {
            let bw = w * 0.59, bh = h * 0.157, sw = w * 0.27, sh = h * 0.052
            let y0 = top ? f.minY : f.maxY - bh
            p.addRect(CGRect(x: r.midX - bw / 2, y: y0, width: bw, height: bh))
            let y1 = top ? f.minY : f.maxY - sh
            p.addRect(CGRect(x: r.midX - sw / 2, y: y1, width: sw, height: sh))
        }
        return p
    }
}

/// Ein Spieler auf dem Feld: Kreis mit Rückennummer, Nachname, Zeichen für Tor, Karte und Wechsel
struct PitchPlayer: View {
    let p: MatchDetail.Player
    let home: Bool
    var compact = false

    private var size: CGFloat { compact ? 28 : 34 }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(home ? Color.white : Color(white: 0.13))
                Text(p.nr).font(.system(size: compact ? 12 : 14, weight: .bold).monospacedDigit())
                    .foregroundColor(home ? Color(white: 0.11) : .white)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
            .overlay(alignment: .topTrailing) { goalBadge.offset(x: 8, y: -5) }
            .overlay(alignment: .topLeading) { cardBadge.offset(x: -5, y: -3) }
            Text(p.last)
                .font(.system(size: compact ? 10.5 : 12, weight: .semibold))
                .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.35), radius: 1)
            if let m = p.subMinute {
                HStack(spacing: 1) {
                    Image(systemName: "arrow.down").font(.system(size: 8, weight: .bold))
                    Text(m).font(.system(size: compact ? 9 : 10).monospacedDigit())
                }
                .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    @ViewBuilder private var goalBadge: some View {
        let g = p.goals + (p.has("own") ? 1 : 0)
        if g > 0 {
            HStack(spacing: 0) {
                Text("⚽️").font(.system(size: compact ? 11 : 13))
                if g > 1 { Text("\(g)").font(.system(size: 10, weight: .bold)).foregroundColor(.white) }
            }
        }
    }

    @ViewBuilder private var cardBadge: some View {
        if p.has("red") || p.has("yellowred") {
            CardShape(color: .red, second: p.has("yellowred"))
        } else if p.has("yellow") {
            CardShape(color: .yellow, second: false)
        }
    }
}

/// Kleine Karte; Gelb-Rot als zwei versetzte Karten
struct CardShape: View {
    let color: Color
    let second: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            if second { RoundedRectangle(cornerRadius: 1.5).fill(Color.yellow).frame(width: 8, height: 11) }
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 8, height: 11)
                .offset(x: second ? 3 : 0, y: second ? 2 : 0)
        }
    }
}
