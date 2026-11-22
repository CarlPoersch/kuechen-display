import SwiftUI

// ============================================================
// Sonne & Tageslänge: Auf- und Untergang, Sonnenbahn über den Tag,
// wie viel Licht dazukommt, Sonnenwende, Dämmerung, Goldene/Blaue Stunde,
// Mondphase und die Tageslänge übers Jahr.
// Alles wird auf dem Gerät berechnet (Sonnenstands-Formel, Genauigkeit ~1 min) –
// kein Internet, kein Laden.
// Einstellungen: city, lat, lon (wie beim Wetter; Standard Regensburg)
// ============================================================

enum SunBucket {
    static let kind = BucketKind(
        id: "sonne", name: "Sonne & Tageslänge", symbol: "sunrise.fill", tint: .orange, art: .glance,
        interests: ["wetter"], blurb: "Auf- und Untergang, Sonnenbahn, wie viel Licht dazukommt – und wann die Tage wieder länger werden.",
        defaultConfig: ["city": .string("Regensburg"), "lat": .number(49.0134), "lon": .number(12.1016)],
        glance: { inst, _ in AnyView(SunGlance(config: inst.config)) },
        detail: { inst in AnyView(SunDetail(config: inst.config)) },
        settings: { binding in AnyView(CityPicker(config: binding)) }
    )

    static func place(_ c: [String: JSON]) -> (lat: Double, lon: Double, city: String) {
        (c["lat"]?.double ?? 49.0134, c["lon"]?.double ?? 12.1016, c["city"]?.string ?? "Regensburg")
    }
}

// MARK: Rechnen

/// Ein Tag aus Sicht der Sonne
struct SunDay {
    let day: Date            // Tagesbeginn (lokal)
    let rise: Date?          // Aufgang (−0,833°: Oberrand am Horizont, mit Lichtbrechung)
    let set: Date?
    let noon: Date           // Höchststand
    let dawn: Date?          // bürgerliche Morgendämmerung beginnt (−6°)
    let dusk: Date?          // bürgerliche Abenddämmerung endet (−6°)
    let blueMorningEnd: Date?, blueEveningStart: Date?      // Blaue Stunde: −6° … −4°
    let goldenMorningEnd: Date?, goldenEveningStart: Date?  // Goldene Stunde: −4° … +6°
    let maxElevation: Double

    /// Tageslicht in Sekunden (Polartag/-nacht: 24 h bzw. 0)
    var length: TimeInterval {
        if let r = rise, let s = set { return s.timeIntervalSince(r) }
        return maxElevation > 0 ? 86_400 : 0
    }
}

enum Sun {
    private static let rad = Double.pi / 180
    static func jd(_ d: Date) -> Double { d.timeIntervalSince1970 / 86_400 + 2_440_587.5 }
    static func date(_ j: Double) -> Date { Date(timeIntervalSince1970: (j - 2_440_587.5) * 86_400) }

    private struct Core { let transit: Double; let decl: Double }

    /// Sonnenhöchststand (Julianisches Datum) und Deklination des Tages
    private static func core(_ day: Date, lon: Double) -> Core {
        let noonLocal = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        let n = (jd(noonLocal) - 2_451_545.0 + 0.0008).rounded(.up)
        let js = n - lon / 360
        let m = (357.5291 + 0.98560028 * js).truncatingRemainder(dividingBy: 360)
        let c = 1.9148 * sin(m * rad) + 0.02 * sin(2 * m * rad) + 0.0003 * sin(3 * m * rad)
        let l = (m + c + 180 + 102.9372).truncatingRemainder(dividingBy: 360)
        let transit = 2_451_545.0 + js + 0.0053 * sin(m * rad) - 0.0069 * sin(2 * l * rad)
        return Core(transit: transit, decl: asin(sin(l * rad) * sin(23.4397 * rad)))
    }

    /// Wann die Sonne die Höhe h (Grad) erreicht: (morgens, abends); nil = erreicht sie an dem Tag nicht
    private static func cross(_ c: Core, lat: Double, h: Double) -> (Date, Date)? {
        let phi = lat * rad
        let cw = (sin(h * rad) - sin(phi) * sin(c.decl)) / (cos(phi) * cos(c.decl))
        guard cw >= -1, cw <= 1 else { return nil }
        let w = acos(cw) / rad
        return (date(c.transit - w / 360), date(c.transit + w / 360))
    }

    static func day(_ d: Date, lat: Double, lon: Double) -> SunDay {
        let start = Calendar.current.startOfDay(for: d)
        let c = core(start, lon: lon)
        let sun = cross(c, lat: lat, h: -0.833), civil = cross(c, lat: lat, h: -6)
        let blue = cross(c, lat: lat, h: -4), golden = cross(c, lat: lat, h: 6)
        let maxE = 90 - abs(lat - c.decl / rad)
        return SunDay(day: start, rise: sun?.0, set: sun?.1, noon: date(c.transit), dawn: civil?.0, dusk: civil?.1,
                      blueMorningEnd: blue?.0, blueEveningStart: blue?.1,
                      goldenMorningEnd: golden?.0, goldenEveningStart: golden?.1, maxElevation: maxE)
    }

    /// Sonnenhöhe in Grad zu einem Zeitpunkt
    static func elevation(_ t: Date, lat: Double, lon: Double) -> Double {
        let c = core(Calendar.current.startOfDay(for: t), lon: lon)
        let h = (jd(t) - c.transit) * 360 * rad
        let phi = lat * rad
        return asin(sin(phi) * sin(c.decl) + cos(phi) * cos(c.decl) * cos(h)) / rad
    }

    /// Deklination am Mittag (für die Sonnenwende)
    static func declination(_ d: Date, lon: Double) -> Double { core(Calendar.current.startOfDay(for: d), lon: lon).decl / rad }

    /// Sonnenwenden im Vorjahr, diesem und nächstem Jahr (Tag mit der größten Deklination im Juni
    /// bzw. kleinsten im Dezember). winter = kürzester Tag am Ort (Nordhalbkugel Dezember, Südhalbkugel Juni)
    private static func solstices(around d: Date, lat: Double, lon: Double) -> [(date: Date, winter: Bool)] {
        let cal = Calendar.current
        let y = cal.component(.year, from: d)
        var out: [(date: Date, winter: Bool)] = []
        for year in (y - 1)...(y + 1) {
            for month in [6, 12] {
                var pick: Date?, ext = 0.0
                for dayN in 17...25 {
                    guard let t = cal.date(from: DateComponents(year: year, month: month, day: dayN)) else { continue }
                    let dec = declination(t, lon: lon) * (month == 6 ? 1 : -1)
                    if pick == nil || dec > ext { pick = t; ext = dec }
                }
                if let p = pick { out.append((p, (month == 12) == (lat >= 0))) }
            }
        }
        return out
    }

    /// Nächste Sonnenwende ab heute (heute eingeschlossen)
    static func solstice(after d: Date, lat: Double, lon: Double) -> (date: Date, winter: Bool) {
        let today = Calendar.current.startOfDay(for: d)
        return solstices(around: d, lat: lat, lon: lon).filter { $0.date >= today }.min { $0.date < $1.date } ?? (today, true)
    }

    /// Letzte Sonnenwende vor heute
    static func lastSolstice(before d: Date, lat: Double, lon: Double) -> (date: Date, winter: Bool) {
        let today = Calendar.current.startOfDay(for: d)
        return solstices(around: d, lat: lat, lon: lon).filter { $0.date < today }.max { $0.date < $1.date } ?? (today, true)
    }
}

enum Moon {
    static let synodic = 29.530588853
    /// Alter in Tagen seit Neumond (Bezug: Neumond 6.1.2000)
    static func age(_ d: Date) -> Double {
        let a = (Sun.jd(d) - 2_451_550.26).truncatingRemainder(dividingBy: synodic)
        return a < 0 ? a + synodic : a
    }
    static func illumination(_ d: Date) -> Double { (1 - cos(2 * Double.pi * age(d) / synodic)) / 2 }

    static func phase(_ d: Date) -> (name: String, symbol: String) {
        switch age(d) {
        case ..<1.85: return ("Neumond", "moonphase.new.moon")
        case ..<5.54: return ("Zunehmende Sichel", "moonphase.waxing.crescent")
        case ..<9.23: return ("Erstes Viertel", "moonphase.first.quarter")
        case ..<12.92: return ("Zunehmender Mond", "moonphase.waxing.gibbous")
        case ..<16.61: return ("Vollmond", "moonphase.full.moon")
        case ..<20.30: return ("Abnehmender Mond", "moonphase.waning.gibbous")
        case ..<23.99: return ("Letztes Viertel", "moonphase.last.quarter")
        case ..<27.68: return ("Abnehmende Sichel", "moonphase.waning.crescent")
        default: return ("Neumond", "moonphase.new.moon")
        }
    }
    /// Nächster Voll- bzw. Neumond
    static func next(full: Bool, after d: Date) -> Date {
        let target = full ? synodic / 2 : 0
        var dt = target - age(d)
        if dt <= 0.2 { dt += synodic }
        return d.addingTimeInterval(dt * 86_400)
    }
}

enum SunFmt {
    /// „8 h 52 min“
    static func length(_ s: TimeInterval) -> String {
        let m = Int((s / 60).rounded())
        return "\(m / 60) h \(m % 60) min"
    }
    /// „+2 min 3 s“, „−48 s“
    static func delta(_ s: TimeInterval) -> String {
        let v = Int(s.rounded()), sign = v < 0 ? "−" : "+", a = abs(v)
        if a >= 3600 { return sign + "\(a / 3600) h \((a % 3600) / 60) min" }
        if a >= 60 { return sign + "\(a / 60) min" + (a % 60 > 0 ? " \(a % 60) s" : "") }
        return sign + "\(a) s"
    }
    static func dayMonth(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "d. MMMM"; return f.string(from: d)
    }
    static func weekday(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEEE"; return f.string(from: d)
    }
    static func days(_ n: Int) -> String { n == 1 ? "1 Tag" : "\(n) Tagen" }
}

/// Die Zeile, die zum Datum passt: Countdown vor der Sonnenwende, danach „seit der Sonnenwende“
struct SunTrend {
    let text: String
    let symbol: String

    static func make(now: Date, lat: Double, lon: Double) -> SunTrend {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let next = Sun.solstice(after: today, lat: lat, lon: lon)
        let left = cal.dateComponents([.day], from: today, to: next.date).day ?? 0
        let name = next.winter ? "Wintersonnenwende" : "Sommersonnenwende"
        if left == 0 {
            return SunTrend(text: "Heute ist " + name + (next.winter ? " – ab morgen wird's heller" : " – der längste Tag"),
                            symbol: next.winter ? "sparkles" : "sun.max.fill")
        }
        if left <= 45 {
            return SunTrend(text: "In " + SunFmt.days(left) + " ist " + name + (next.winter ? ", dann wird's wieder heller" : ""),
                            symbol: "calendar")
        }
        let last = Sun.lastSolstice(before: today, lat: lat, lon: lon)
        let gain = Sun.day(today, lat: lat, lon: lon).length - Sun.day(last.date, lat: lat, lon: lon).length
        return SunTrend(text: SunFmt.delta(gain) + " Licht seit der " + (last.winter ? "Wintersonnenwende" : "Sommersonnenwende"),
                        symbol: gain >= 0 ? "arrow.up.right" : "arrow.down.right")
    }
}

// MARK: Sonnenbahn

/// Sonnenhöhe über den ganzen Tag – wie in Apple Wetter: Bogen über dem Horizont,
/// Punkt = jetzt. Unter dem Horizont grau.
struct SunCurve: View {
    let lat: Double
    let lon: Double
    let now: Date
    var marks: [Date] = []     // senkrechte Hilfslinien (z. B. Auf-/Untergang)

    var body: some View {
        let start = Calendar.current.startOfDay(for: now)
        let samples: [Double] = (0...96).map { Sun.elevation(start.addingTimeInterval(Double($0) * 900), lat: lat, lon: lon) }
        let top = max(10, samples.max() ?? 10), bottom = min(-10, samples.min() ?? -10)
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let y: (Double) -> CGFloat = { e in CGFloat((top - e) / (top - bottom)) * h }
            let x: (Date) -> CGFloat = { t in CGFloat(t.timeIntervalSince(start) / 86_400) * w }
            let horizon = y(0)
            let curve = Path { p in
                for (i, e) in samples.enumerated() {
                    let pt = CGPoint(x: w * CGFloat(i) / 96, y: y(e))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
            let nowE = Sun.elevation(now, lat: lat, lon: lon)
            ZStack(alignment: .topLeading) {
                // Fläche über dem Horizont
                Path { p in
                    p.addPath(curve)
                    p.addLine(to: CGPoint(x: w, y: horizon)); p.addLine(to: CGPoint(x: 0, y: horizon)); p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color.orange.opacity(0.28), Color.orange.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                .clipShape(Rectangle().size(width: w, height: max(0, horizon)))
                // Linie: unten grau, oben warm
                curve.stroke(Color.gray.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 4]))
                curve.stroke(LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .top, endPoint: .bottom),
                             style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .clipShape(Rectangle().size(width: w, height: max(0, horizon)))
                // Horizont
                Rectangle().fill(Theme.secondary.opacity(0.35)).frame(width: w, height: 1).offset(y: horizon)
                ForEach(marks, id: \.self) { m in
                    Rectangle().fill(Theme.secondary.opacity(0.25)).frame(width: 1, height: h).offset(x: x(m))
                }
                // Jetzt
                Circle()
                    .fill(nowE > 0 ? Color.yellow : Color(UIColor.systemIndigo))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                    .shadow(color: (nowE > 0 ? Color.orange : Color.black).opacity(0.35), radius: 4)
                    .offset(x: x(now) - 7, y: y(nowE) - 7)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Karte

struct SunGlance: View {
    let config: [String: JSON]
    @Environment(\.glanceSpace) private var space

    var body: some View {
        let p = SunBucket.place(config)
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let now = ctx.date
            let today = Sun.day(now, lat: p.lat, lon: p.lon)
            let yesterday = Sun.day(now.addingTimeInterval(-86_400), lat: p.lat, lon: p.lon)
            let trend = SunTrend.make(now: now, lat: p.lat, lon: p.lon)
            let curveH = min(110, space.height - 92)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    time("sunrise.fill", today.rise, past: today.rise.map { $0 < now } ?? false)
                    time("sunset.fill", today.set, past: today.set.map { $0 < now } ?? false)
                    Spacer(minLength: 0)
                }
                if curveH >= 44 {
                    SunCurve(lat: p.lat, lon: p.lon, now: now).frame(height: curveH)
                }
                VStack(alignment: .leading, spacing: 3) {
                    (Text(SunFmt.length(today.length)).foregroundColor(.primary).fontWeight(.semibold)
                     + Text(" Tageslicht · " + SunFmt.delta(today.length - yesterday.length) + " zu gestern"))
                        .font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary).lineLimit(1).minimumScaleFactor(0.8)
                    if space.height > 96 {
                        Label(trend.text, systemImage: trend.symbol)
                            .font(.caption.weight(.medium)).foregroundColor(Theme.secondary).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func time(_ symbol: String, _ t: Date?, past: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).symbolRenderingMode(.multicolor).font(.title3)
            Text(t.map { Fmt.hhmm($0) } ?? "–").font(.title2.weight(.semibold).monospacedDigit())
                .foregroundColor(past ? Theme.secondary : .primary)
        }
    }
}

// MARK: Detail

struct SunDetail: View {
    let config: [String: JSON]

    var body: some View {
        let p = SunBucket.place(config)
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let now = ctx.date
            let d = Sun.day(now, lat: p.lat, lon: p.lon)
            let y = Sun.day(now.addingTimeInterval(-86_400), lat: p.lat, lon: p.lon)
            let trend = SunTrend.make(now: now, lat: p.lat, lon: p.lon)
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            big("Aufgang", d.rise, symbol: "sunrise.fill")
                            Spacer()
                            big("Höchststand", d.noon, symbol: "sun.max.fill", sub: String(format: "%.0f°", d.maxElevation))
                            Spacer()
                            big("Untergang", d.set, symbol: "sunset.fill")
                        }
                        SunCurve(lat: p.lat, lon: p.lon, now: now, marks: [d.rise, d.set].compactMap { $0 }).frame(height: 150)
                        HStack {
                            Text("0 Uhr"); Spacer(); Text("12 Uhr"); Spacer(); Text("24 Uhr")
                        }
                        .font(.caption2).foregroundColor(Theme.secondary)
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text(p.city + " · berechnet auf dem Gerät, auf etwa 1 Minute genau")
                }

                Section("Heute") {
                    row("Tageslicht", SunFmt.length(d.length), symbol: "sun.max")
                    row("Zu gestern", SunFmt.delta(d.length - y.length) , symbol: d.length >= y.length ? "arrow.up.right" : "arrow.down.right")
                    row("Hell ab", d.dawn.map { Fmt.hhmm($0) } ?? "–", symbol: "sun.haze", sub: "Morgendämmerung")
                    row("Dunkel ab", d.dusk.map { Fmt.hhmm($0) } ?? "–", symbol: "moon.haze", sub: "Ende der Abenddämmerung")
                }

                Section {
                    span("Goldene Stunde morgens", d.blueMorningEnd, d.goldenMorningEnd, symbol: "camera.aperture", tint: .orange)
                    span("Goldene Stunde abends", d.goldenEveningStart, d.blueEveningStart, symbol: "camera.aperture", tint: .orange)
                    span("Blaue Stunde morgens", d.dawn, d.blueMorningEnd, symbol: "camera.aperture", tint: .blue)
                    span("Blaue Stunde abends", d.blueEveningStart, d.dusk, symbol: "camera.aperture", tint: .blue)
                } header: { Text("Fotolicht") } footer: {
                    Text("Goldene Stunde: warmes, weiches Licht kurz nach Aufgang und vor Untergang. Blaue Stunde: tiefblauer Himmel in der Dämmerung.")
                }

                Section("Mond") {
                    let ph = Moon.phase(now)
                    HStack(spacing: 14) {
                        Image(systemName: ph.symbol).font(.system(size: 34)).foregroundColor(Color(UIColor.systemIndigo)).frame(width: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ph.name).font(.headline)
                            Text("\(Int((Moon.illumination(now) * 100).rounded())) % beleuchtet").font(.subheadline).foregroundColor(Theme.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    row("Nächster Vollmond", moonDate(Moon.next(full: true, after: now)), symbol: "moonphase.full.moon")
                    row("Nächster Neumond", moonDate(Moon.next(full: false, after: now)), symbol: "moonphase.new.moon")
                }

                Section {
                    YearDaylight(lat: p.lat, lon: p.lon, now: now).frame(height: 170).padding(.vertical, 8)
                    Label(trend.text, systemImage: trend.symbol).font(.subheadline)
                } header: { Text("Übers Jahr") }

                Section("Die nächsten Tage") {
                    ForEach(1...7, id: \.self) { i in
                        let t = Calendar.current.date(byAdding: .day, value: i, to: now) ?? now
                        let a = Sun.day(t, lat: p.lat, lon: p.lon)
                        let b = Sun.day(t.addingTimeInterval(-86_400), lat: p.lat, lon: p.lon)
                        HStack {
                            Text(i == 1 ? "Morgen" : SunFmt.weekday(t)).frame(width: 96, alignment: .leading)
                            Spacer()
                            Text(a.rise.map { Fmt.hhmm($0) } ?? "–").frame(width: 50, alignment: .trailing)
                            Text(a.set.map { Fmt.hhmm($0) } ?? "–").frame(width: 50, alignment: .trailing)
                            Text(SunFmt.delta(a.length - b.length)).foregroundColor(Theme.secondary).frame(width: 82, alignment: .trailing)
                        }
                        .font(.subheadline.monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Sonne")
    }

    private func moonDate(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEE, d. MMM"; return f.string(from: d)
    }

    private func big(_ title: String, _ t: Date?, symbol: String, sub: String? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).symbolRenderingMode(.multicolor).font(.title2)
            Text(t.map { Fmt.hhmm($0) } ?? "–").font(.title2.weight(.semibold).monospacedDigit())
            Text(sub.map { title + " · " + $0 } ?? title).font(.caption).foregroundColor(Theme.secondary)
        }
    }

    private func row(_ title: String, _ value: String, symbol: String, sub: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundColor(.orange).frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let s = sub { Text(s).font(.caption).foregroundColor(Theme.secondary) }
            }
            Spacer()
            Text(value).font(.body.monospacedDigit()).foregroundColor(Theme.secondary)
        }
    }

    private func span(_ title: String, _ a: Date?, _ b: Date?, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundColor(tint).frame(width: 26)
            Text(title)
            Spacer()
            Text(a != nil && b != nil ? Fmt.hhmm(a!) + "–" + Fmt.hhmm(b!) : "–")
                .font(.body.monospacedDigit()).foregroundColor(Theme.secondary)
        }
    }
}

/// Tageslänge über das ganze Jahr, Punkt = heute; kürzester und längster Tag beschriftet
struct YearDaylight: View {
    let lat: Double
    let lon: Double
    let now: Date

    var body: some View {
        let cal = Calendar.current
        let year = cal.component(.year, from: now)
        let first = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let count = cal.range(of: .day, in: .year, for: now)?.count ?? 365
        let days: [Date] = (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: first) }
        let len: [Double] = days.map { Sun.day($0, lat: lat, lon: lon).length / 3600 }
        let todayIndex = max(0, min(count - 1, (cal.dateComponents([.day], from: first, to: cal.startOfDay(for: now)).day ?? 0)))
        let lo = len.min() ?? 0, hi = len.max() ?? 24
        let minI = len.firstIndex(of: lo) ?? 0, maxI = len.firstIndex(of: hi) ?? 0
        VStack(spacing: 6) {
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                let pad = (hi - lo) * 0.15 + 0.5
                let y: (Double) -> CGFloat = { v in CGFloat((hi + pad - v) / ((hi + pad) - (lo - pad))) * h }
                let x: (Int) -> CGFloat = { i in w * CGFloat(i) / CGFloat(max(1, count - 1)) }
                let line = Path { p in
                    for (i, v) in len.enumerated() {
                        let pt = CGPoint(x: x(i), y: y(v))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                ZStack(alignment: .topLeading) {
                    Path { p in p.addPath(line); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath() }
                        .fill(LinearGradient(colors: [Color.orange.opacity(0.22), Color.orange.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    line.stroke(Color.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    // Monatsstriche
                    ForEach(0..<12, id: \.self) { m in
                        let d = cal.date(from: DateComponents(year: year, month: m + 1, day: 1)) ?? first
                        let i = cal.dateComponents([.day], from: first, to: d).day ?? 0
                        Rectangle().fill(Theme.secondary.opacity(0.15)).frame(width: 1, height: h).offset(x: x(i))
                    }
                    label(SunFmt.length(hi * 3600), at: CGPoint(x: x(maxI), y: y(hi)), above: true, w: w)
                    label(SunFmt.length(lo * 3600), at: CGPoint(x: x(minI), y: y(lo)), above: true, w: w)
                    Circle().fill(Theme.accent).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .offset(x: x(todayIndex) - 6, y: y(len[todayIndex]) - 6)
                }
            }
            HStack {
                ForEach(["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"].indices, id: \.self) { i in
                    Text(["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"][i]).font(.caption2).foregroundColor(Theme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tageslänge übers Jahr: kürzester Tag \(SunFmt.length(lo * 3600)), längster \(SunFmt.length(hi * 3600))")
    }

    private func label(_ text: String, at p: CGPoint, above: Bool, w: CGFloat) -> some View {
        Text(text).font(.caption2.weight(.semibold).monospacedDigit()).foregroundColor(Theme.secondary)
            .fixedSize()
            .frame(width: 80)
            .offset(x: min(max(0, p.x - 40), w - 80), y: above ? p.y - 18 : p.y + 4)
    }
}
