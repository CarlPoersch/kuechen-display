import SwiftUI
import Combine

/// Jeder Bucket ist eine App (Symbol unten bei APPS, öffnet die Detailansicht) und kann ein Widget
/// (Karte oben) haben. Beides ist pro Gerät einzeln ein-/ausblendbar.
/// Glance = mit Widget (+ App, wenn es eine Detailansicht gibt), Tool = nur App,
/// Button = runder Knopf unten rechts (z. B. Gäste-WLAN, ohne App)
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
    /// Widget einer anderen App (z. B. Einkauf → Küche): kein eigenes App-Symbol
    var parent: String? = nil
    /// false = nicht mehr im Katalog (bestehende Karten laufen weiter)
    var inCatalog = true
    /// Mehrere Ansichten in einer Karte (z. B. Einkauf ↔ Vorrat). Umschalten über den Titel im Kartenkopf.
    var modes: [BucketMode] = []
}

/// Eine Ansicht einer Karte mit mehreren Themen
struct BucketMode: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
}

/// Merkt sich pro Karte, welche Ansicht gerade gewählt ist – pro Gerät (iPhone und iPad dürfen
/// verschiedene Ansichten zeigen, die Inhalte bleiben gleich).
final class BucketModes: ObservableObject {
    static let shared = BucketModes()
    private let key = "hubert.bucketModes"
    @Published private var values: [String: String]

    init() { values = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:] }

    func mode(_ bucketId: String, default first: String) -> String { values[bucketId] ?? first }
    func mode(_ bucketId: String, kind: BucketKind) -> BucketMode? {
        let id = values[bucketId]
        return kind.modes.first { $0.id == id } ?? kind.modes.first
    }
    func set(_ bucketId: String, _ mode: String) {
        values[bucketId] = mode
        UserDefaults.standard.set(values, forKey: key)
    }
}

extension BucketKind {
    /// Hat ein eigenes App-Symbol unten bei APPS
    var hasApp: Bool { available && art != .button && parent == nil && detail != nil }
    /// Hat ein Widget (Karte oben auf der Startseite)
    var hasWidget: Bool { art == .glance }
    /// Name der App, zu der dieses Widget gehört
    var parentName: String? { parent.flatMap { BucketRegistry.kind($0)?.name } }
}

/// Alle Buckets, die es gibt
enum BucketRegistry {
    static let all: [BucketKind] = [WeatherBucket.kind, SunBucket.kind, TermineBucket.kind, NewsBucket.kind, SportBucket.kind, DealsBucket.kind, TransitBucket.kind, CountdownBucket.kind,
                                         KitchenBuckets.kitchen, KitchenBuckets.shopping, KitchenBuckets.recipeOfDay,
                                         KitchenBuckets.timer, GuestWifiBucket.kind, MensaBucket.kind, FilmBucket.kind, FocusBucket.kind,
                                         PollenBucket.kind, ReiseBucket.kind, StundenplanBucket.kind, ZieleBucket.kind, StromBucket.kind,
                                         RemoteBucket.kind, SpotifyBucket.kind, SmartHomeBucket.kind] + comingSoon

    static func kind(_ id: String) -> BucketKind? { all.first { $0.id == id } }
    /// Was man hinzufügen kann (Katalog, Einrichtung)
    static var catalog: [BucketKind] { all.filter { $0.inCatalog } }

    /// Schon im Katalog sichtbar, kommt in den nächsten Etappen
    static let comingSoon: [BucketKind] = [
        soon("lokal", "Lokalnachrichten", "building.2", .brown, .glance, ["news"], "Was in deiner Stadt los ist."),
        soon("tech", "Tech-Releases", "cpu", .gray, .glance, ["technik"], "Neue Software, KI-Modelle, Apple-Events."),
        soon("tanken", "Tankpreise", "fuelpump", .green, .glance, ["unterwegs"], "Günstigste Tankstelle in der Nähe."),
        soon("pakete", "Pakete", "shippingbox", .brown, .glance, ["haushalt"], "Wann kommt deine Sendung?"),
        soon("kasse", "Haushaltskasse", "eurosign.circle", .green, .tool, ["haushalt"], "Wer hat was bezahlt?"),
        soon("schritte", "Schritte", "figure.walk", .pink, .glance, ["gesundheit"], "Aus Apple Health."),
        soon("schlaf", "Schlaf", "bed.double", .indigo, .glance, ["gesundheit"], "Letzte Nacht, aus Apple Health."),
        soon("medikamente", "Medikamente", "pills", .red, .tool, ["gesundheit"], "Erinnern und abhaken."),
        soon("pruefungen", "Prüfungen", "doc.text", .purple, .tool, ["lernen"], "Countdown und Lernplan."),
        soon("events", "Events", "ticket", .purple, .glance, ["freizeit"], "Konzerte und Veranstaltungen in der Nähe."),
        soon("kicktipp", "Kicktipp", "sportscourt", .green, .glance, ["sport"], "Deine Tipps und dein Platz."),
        soon("lesen", "Buch & Serie", "book", .brown, .tool, ["freizeit"], "Fortschritt im Blick."),
        soon("foto", "Foto des Tages", "photo", .teal, .glance, ["freizeit"], "Erinnerungen oder Bilder aus dem All."),
        soon("quiz", "Tagesfrage", "questionmark.bubble", .orange, .glance, ["freizeit"], "Eine Frage pro Tag, Punkte im Haushalt."),
        soon("kochen-heute", "Was koche ich heute?", "flame", .orange, .glance, ["haushalt"], "Passend zu Vorrat, Wetter und Zeit."),
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
