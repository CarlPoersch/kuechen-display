import SwiftUI

/// Glance = anschauen (Briefing oben), Tool = benutzen (App-Symbole unten),
/// Button = runder Knopf unten rechts (z. B. Gäste-WLAN)
enum BucketArt { case glance, tool, button }

/// Beschreibung einer Bucket-Art im Katalog.
/// Ein neuer Bucket = eine neue Datei, die so eine Beschreibung liefert, + Eintrag in BucketRegistry.
struct BucketKind: Identifiable {
    let id: String
    let name: String
    let symbol: String          // SF Symbol
    let tint: Color
    let art: BucketArt
    let interests: [String]     // passende Interessen (Interest.id)
    let blurb: String           // ein Satz für den Katalog
    var available = true        // false = "kommt bald"
    var sizes: [BucketSize] = BucketSize.allCases
    var defaultSize: BucketSize = .m
    var defaultConfig: [String: JSON] = [:]
    /// Muss der Nutzer vor der ersten Nutzung etwas einstellen? (z. B. Stadt)
    var needsSetup: ([String: JSON]) -> Bool = { _ in false }
    /// Ansicht auf der Startseite
    var glance: (BucketInstance, BucketSize) -> AnyView = { _, _ in AnyView(EmptyView()) }
    /// Ansicht nach dem Antippen (nil = nicht antippbar)
    var detail: ((BucketInstance) -> AnyView)? = nil
    /// true = die Einträge in der Karte sind selbst antippbar (News, Sport);
    /// die ganze Karte öffnet dann nicht die Details, nur "Alle ›" im Kopf.
    var itemLinks = false
    /// Einstellungen (nil = nichts einzustellen)
    var settings: ((Binding<[String: JSON]>) -> AnyView)? = nil
}

/// Alle Buckets, die es gibt
enum BucketRegistry {
    static let all: [BucketKind] = [WeatherBucket.kind, SunBucket.kind, TermineBucket.kind, NewsBucket.kind, SportBucket.kind, DealsBucket.kind, TransitBucket.kind, CountdownBucket.kind,
                                         KitchenBuckets.shopping, KitchenBuckets.recipeOfDay,
                                         KitchenBuckets.kitchen, KitchenBuckets.timer, GuestWifiBucket.kind, MensaBucket.kind, FilmBucket.kind] + comingSoon

    static func kind(_ id: String) -> BucketKind? { all.first { $0.id == id } }

    /// Schon im Katalog sichtbar, kommt in den nächsten Etappen
    static let comingSoon: [BucketKind] = [
        soon("pollen", "Pollen & UV", "allergens", .yellow, .glance, ["wetter", "gesundheit"], "Pollenflug und UV-Index."),
        soon("lokal", "Lokalnachrichten", "building.2", .brown, .glance, ["news"], "Was in deiner Stadt los ist."),
        soon("tech", "Tech-Releases", "cpu", .gray, .glance, ["technik"], "Neue Software, KI-Modelle, Apple-Events."),
        soon("reise", "Reise", "airplane", .cyan, .glance, ["unterwegs"], "Countdown, Wetter am Ziel, Packliste."),
        soon("tanken", "Tankpreise", "fuelpump", .green, .glance, ["unterwegs"], "Günstigste Tankstelle in der Nähe."),
        soon("pakete", "Pakete", "shippingbox", .brown, .glance, ["haushalt"], "Wann kommt deine Sendung?"),
        soon("kasse", "Haushaltskasse", "eurosign.circle", .green, .tool, ["haushalt"], "Wer hat was bezahlt?"),
        soon("strom", "Stromverbrauch", "bolt", .yellow, .tool, ["haushalt"], "Zählerstand eintragen, Verlauf sehen."),
        soon("schritte", "Schritte", "figure.walk", .pink, .glance, ["gesundheit"], "Aus Apple Health."),
        soon("schlaf", "Schlaf", "bed.double", .indigo, .glance, ["gesundheit"], "Letzte Nacht, aus Apple Health."),
        soon("medikamente", "Medikamente", "pills", .red, .tool, ["gesundheit"], "Erinnern und abhaken."),
        soon("stundenplan", "Stundenplan", "graduationcap", .blue, .glance, ["lernen"], "Nächste Vorlesung und Raum."),
        soon("pruefungen", "Prüfungen", "pencil.and.list.clipboard", .purple, .tool, ["lernen"], "Countdown und Lernplan."),
        soon("fokus", "Fokus-Timer", "brain.head.profile", .mint, .tool, ["lernen"], "Pomodoro mit Statistik."),
        soon("ziele", "Wochenziele", "checkmark.seal", .green, .tool, ["lernen", "gesundheit"], "Drei Ziele pro Woche."),
        soon("events", "Events", "ticket", .purple, .glance, ["freizeit"], "Konzerte und Veranstaltungen in der Nähe."),
        soon("kicktipp", "Kicktipp", "soccerball", .green, .glance, ["sport"], "Deine Tipps und dein Platz."),
        soon("lesen", "Buch & Serie", "book", .brown, .tool, ["freizeit"], "Fortschritt im Blick."),
        soon("foto", "Foto des Tages", "photo", .teal, .glance, ["freizeit"], "Erinnerungen oder Bilder aus dem All."),
        soon("quiz", "Tagesfrage", "questionmark.bubble", .orange, .glance, ["freizeit"], "Eine Frage pro Tag, Punkte im Haushalt."),
        soon("kochen-heute", "Was koche ich heute?", "frying.pan", .orange, .glance, ["haushalt"], "Passend zu Vorrat, Wetter und Zeit."),
        soon("smarthome", "Smart Home", "lightbulb", .yellow, .tool, ["haushalt", "technik"], "Licht und Geräte steuern."),
    ]

    private static func soon(_ id: String, _ name: String, _ symbol: String, _ tint: Color, _ art: BucketArt,
                             _ interests: [String], _ blurb: String) -> BucketKind {
        BucketKind(id: id, name: name, symbol: symbol, tint: tint, art: art, interests: interests,
                   blurb: blurb, available: false)
    }
}

// MARK: Platz in der Karte

/// Wie viel Platz die Karte ihrem Inhalt lässt. Warum: Damit jeder Bucket
/// genau so viele Einträge zeigt, wie hineinpassen – egal ob iPhone oder iPad.
private struct GlanceSpaceKey: EnvironmentKey { static let defaultValue = CGSize(width: 300, height: 120) }
extension EnvironmentValues {
    var glanceSpace: CGSize {
        get { self[GlanceSpaceKey.self] }
        set { self[GlanceSpaceKey.self] = newValue }
    }
}

/// Öffnet die Einstellungen des Buckets direkt aus der Karte oder den Details
private struct EditBucketKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var editBucket: () -> Void {
        get { self[EditBucketKey.self] }
        set { self[EditBucketKey.self] = newValue }
    }
}

/// Öffnet die Detailansicht der Karte (für Buckets mit eigenen Bedienelementen im Inhalt)
private struct OpenDetailKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var openBucketDetail: () -> Void {
        get { self[OpenDetailKey.self] }
        set { self[OpenDetailKey.self] = newValue }
    }
}

/// Welcher Bucket gerade gezeichnet wird (für Änderungen direkt in der Karte)
private struct BucketIdKey: EnvironmentKey { static let defaultValue = "" }
/// Startseite im Bearbeiten-Modus (wackelnde Karten, verschieben, entfernen)
private struct HomeEditingKey: EnvironmentKey { static let defaultValue = false }
private struct StartEditingKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var bucketId: String {
        get { self[BucketIdKey.self] }
        set { self[BucketIdKey.self] = newValue }
    }
    var homeEditing: Bool {
        get { self[HomeEditingKey.self] }
        set { self[HomeEditingKey.self] = newValue }
    }
    var startHomeEditing: () -> Void {
        get { self[StartEditingKey.self] }
        set { self[StartEditingKey.self] = newValue }
    }
}

/// Wie viele Zeilen der Höhe `row` passen in `height` (mindestens 1, höchstens `max`)
func fitRows(_ height: CGFloat, row: CGFloat, max m: Int = 12) -> Int {
    Swift.max(1, Swift.min(m, Int((height + 4) / row)))
}

/// Hilfen für Bucket-Einstellungen
extension Binding where Value == [String: JSON] {
    /// Textfeld-Bindung auf einen Schlüssel der Einstellungen
    func string(_ key: String) -> Binding<String> {
        Binding<String>(get: { wrappedValue[key]?.string ?? "" },
                        set: { wrappedValue[key] = .string($0) })
    }
}
