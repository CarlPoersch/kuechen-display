import SwiftUI
import Combine

// ============================================================
// Darstellung: Farbthema (Kopfkarte, Leiste, Zurück-Knöpfe, Akzente)
// und Kopfbereich (Größe, Begrüßung, Sekunden, Datum).
// Gilt pro Gerät – so kann das Wand-iPad anders aussehen als das iPhone.
// ============================================================

struct HubertTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let colors: [Color]     // Verlauf der Kopfkarte, hell → dunkel
    let accent: Color       // Knöpfe, Zurück-Pfeile, Hervorhebungen

    var gradient: LinearGradient { LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing) }

    /// Ist die Kopfkarte so hell, dass weiße Schrift untergeht? Maßgeblich ist die linke, hellere Hälfte (dort stehen Uhr und Datum).
    var isLight: Bool {
        let l = colors.prefix(2).map { Self.luminance(UIColor($0)) }
        return l.reduce(0, +) / Double(max(1, l.count)) > 0.6
    }
    /// Schrift und Symbole auf der Kopfkarte: weiß auf dunklen, fast schwarz auf hellen Farben
    var onHeader: Color { isLight ? Color(white: 0.11) : .white }
    /// Hinterlegung für runde Knöpfe auf der Kopfkarte (Zahnrad)
    var onHeaderFill: Color { isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.22) }

    /// Relative Helligkeit nach WCAG (0 = schwarz, 1 = weiß)
    static func luminance(_ c: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ v: CGFloat) -> Double { let x = Double(max(0, min(1, v))); return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }
    var shadow: Color { (colors.last ?? accent).opacity(0.25) }

    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }

    static let all: [HubertTheme] = [
        HubertTheme(id: "hubert", name: "Hubert", colors: [rgb(247, 163, 92), rgb(235, 107, 31), rgb(194, 64, 13)], accent: rgb(232, 89, 12)),
        HubertTheme(id: "ozean", name: "Ozean", colors: [rgb(90, 200, 250), rgb(10, 132, 255), rgb(0, 82, 180)], accent: rgb(0, 122, 255)),
        HubertTheme(id: "wald", name: "Wald", colors: [rgb(124, 214, 140), rgb(52, 170, 89), rgb(22, 110, 60)], accent: rgb(40, 150, 75)),
        HubertTheme(id: "lagune", name: "Lagune", colors: [rgb(100, 220, 210), rgb(28, 170, 170), rgb(10, 105, 120)], accent: rgb(18, 150, 155)),
        HubertTheme(id: "beere", name: "Beere", colors: [rgb(240, 120, 190), rgb(205, 55, 140), rgb(140, 25, 95)], accent: rgb(200, 45, 130)),
        HubertTheme(id: "abend", name: "Abend", colors: [rgb(160, 140, 255), rgb(110, 85, 230), rgb(65, 40, 160)], accent: rgb(100, 80, 220)),
        HubertTheme(id: "koralle", name: "Koralle", colors: [rgb(255, 150, 130), rgb(240, 85, 80), rgb(180, 40, 50)], accent: rgb(230, 70, 70)),
        HubertTheme(id: "graphit", name: "Graphit", colors: [rgb(120, 125, 135), rgb(72, 76, 86), rgb(34, 36, 42)], accent: rgb(90, 95, 110)),
    ]

    /// Eigenes Thema aus einer Farbe: hellere und dunklere Stufe automatisch
    static func custom(_ c: UIColor) -> HubertTheme {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let light = UIColor(hue: h, saturation: s * 0.7, brightness: min(1, b * 1.12 + 0.05), alpha: 1)
        let dark = UIColor(hue: h, saturation: min(1, s * 1.05), brightness: b * 0.62, alpha: 1)
        // Sehr helle Farbe (z. B. Weiß): Akzent abdunkeln, sonst sind Knöpfe auf weißen Karten unsichtbar
        let accent = luminance(c) > 0.6 ? UIColor(hue: h, saturation: s, brightness: min(b, 0.45), alpha: 1) : c
        return HubertTheme(id: "eigene", name: "Eigene", colors: [Color(light), Color(c), Color(dark)], accent: Color(accent))
    }
}

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()
    private let d = UserDefaults.standard

    @Published var themeId: String { didSet { d.set(themeId, forKey: "theme.id") } }
    @Published var customHex: String { didSet { d.set(customHex, forKey: "theme.custom") } }
    @Published var compactHeader: Bool { didSet { d.set(compactHeader, forKey: "header.compact") } }
    @Published var showGreeting: Bool { didSet { d.set(showGreeting, forKey: "header.greeting") } }
    @Published var showSeconds: Bool { didSet { d.set(showSeconds, forKey: "header.seconds") } }
    @Published var showDate: Bool { didSet { d.set(showDate, forKey: "header.date") } }

    init() {
        themeId = d.string(forKey: "theme.id") ?? "hubert"
        customHex = d.string(forKey: "theme.custom") ?? "#E8590C"
        compactHeader = d.bool(forKey: "header.compact")
        showGreeting = d.object(forKey: "header.greeting") as? Bool ?? true
        showSeconds = d.bool(forKey: "header.seconds")
        showDate = d.object(forKey: "header.date") as? Bool ?? true
    }

    var current: HubertTheme {
        if themeId == "eigene" { return HubertTheme.custom(UIColor(hex: customHex) ?? .systemOrange) }
        return HubertTheme.all.first { $0.id == themeId } ?? HubertTheme.all[0]
    }

    /// Ändert sich beim Themawechsel – damit sich alle Ansichten neu einfärben
    var refreshKey: String { themeId + customHex }

    var customColor: Color {
        get { Color(UIColor(hex: customHex) ?? .systemOrange) }
        set { customHex = UIColor(newValue).hex; themeId = "eigene" }
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }
}
