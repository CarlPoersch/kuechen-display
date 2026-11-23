import SwiftUI

// ============================================================
// Packliste passend zur Reise – ohne KI, aus Bausteinen:
// Grundliste + Pakete je nach Wetter am Ziel, Land, Dauer und Reiseart.
// Jedes Paket nennt den Grund („In Thailand andere Steckdosen“).
// Die Vorschläge landen nur in der Liste, wenn man sie übernimmt.
// ============================================================

enum TripKind: String, CaseIterable, Identifiable {
    case stadt, strand, ski, wandern, business
    var id: String { rawValue }
    var label: String {
        switch self {
        case .stadt: return "Städtetrip"
        case .strand: return "Strand"
        case .ski: return "Ski"
        case .wandern: return "Wandern"
        case .business: return "Geschäftlich"
        }
    }
    var emoji: String {
        switch self {
        case .stadt: return "🏙️"
        case .strand: return "🏖️"
        case .ski: return "⛷️"
        case .wandern: return "🥾"
        case .business: return "💼"
        }
    }
}

struct PackPackage: Identifiable {
    let id: String
    let title: String
    let reason: String
    let items: [String]
}

enum PackPlanner {
    /// Wetter am Ziel, zusammengefasst aus Vorhersage und Schätzung
    struct Climate { let max: Double; let min: Double; let wetShare: Double }

    static func climate(_ days: [TripWeatherDay]) -> Climate? {
        guard !days.isEmpty else { return nil }
        let n = Double(days.count)
        return Climate(max: days.map(\.max).reduce(0, +) / n, min: days.map(\.min).reduce(0, +) / n,
                       wetShare: Double(days.filter { $0.rain >= 50 }.count) / n)
    }

    // EU/EWR + Schweiz: Personalausweis reicht, EU-Krankenversicherungskarte gilt, Roaming inklusive
    private static let europeID: Set<String> = ["DE", "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "GR", "HU", "IE",
                                                "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
                                                "IS", "LI", "NO", "CH"]
    // Europa im weiteren Sinn (kein Langstreckenflug)
    private static let europe: Set<String> = europeID.union(["GB", "AL", "BA", "ME", "MK", "RS", "XK", "MD", "UA", "TR", "MC", "SM", "AD", "VA"])

    /// Steckdosen, in die deutsche Stecker (Typ C/F) nicht oder nur wackelig passen
    private static let plugs: [String: String] = [
        "GB": "G", "IE": "G", "MT": "G", "CY": "G", "HK": "G", "SG": "G", "MY": "G", "AE": "G", "QA": "G", "KE": "G",
        "US": "A/B", "CA": "A/B", "MX": "A/B", "JP": "A/B", "PH": "A/B", "CU": "A/B", "DO": "A/B", "CR": "A/B", "PA": "A/B",
        "TH": "A/B/O", "VN": "A", "TW": "A/B", "CO": "A/B", "PE": "A/C", "AU": "I", "NZ": "I", "CN": "A/I", "AR": "I",
        "ZA": "M/N", "BR": "N", "IN": "D/M", "LK": "D/G", "NP": "D/M", "MV": "G/D", "IL": "H", "MU": "G/C", "SC": "G",
    ]

    static func packages(kind: TripKind?, country cc: String, lat: Double, nights: Int, climate: Climate?) -> [PackPackage] {
        var out: [PackPackage] = []
        let cc = cc.uppercased()
        let known = !cc.isEmpty
        let inEU = !known || europeID.contains(cc)
        let farAway = known && !europe.contains(cc)
        let tropics = abs(lat) > 0.01 && abs(lat) < 23.5
        let days = max(1, nights + 1)

        // Grundliste
        out.append(PackPackage(id: "basis", title: "Für jede Reise", reason: "Das Übliche – Mengen passend zu \(days) Tag\(days == 1 ? "" : "en").", items: [
            inEU ? "Personalausweis" : "Reisepass", "Tickets / Buchungen", "Geldbeutel & Karten", "Handy & Ladekabel", "Powerbank",
            "Kopfhörer", "Schlüssel", "Zahnbürste & Zahnpasta", "Duschzeug", "Deo", "Medikamente",
            "Unterwäsche × \(min(days, 8))", "Socken × \(min(days, 8))", "T-Shirts × \(min(days, 7))",
            "Hosen × \(days > 4 ? 2 : 1)", "Schlafsachen",
        ]))

        // Land
        if known && !inEU {
            out.append(PackPackage(id: "ausland", title: "Außerhalb der EU", reason: "Reisepass statt Ausweis, die EU-Krankenkarte gilt nicht, Roaming kostet extra.", items: [
                "Reisepass (6 Monate gültig?)", "Visum / Einreise prüfen", "Auslandskrankenversicherung", "Kreditkarte",
                "Kopie wichtiger Dokumente", "eSIM / Datenpaket",
            ]))
        }
        if let p = plugs[cc] {
            out.append(PackPackage(id: "strom", title: "Andere Steckdosen", reason: "Dort gibt es Steckdosen Typ \(p) – deutsche Stecker passen nicht oder wackeln.",
                                   items: ["Reiseadapter (Typ \(p))", "Mehrfachstecker"]))
        }
        if farAway {
            out.append(PackPackage(id: "flug", title: "Langer Flug", reason: "Fernreise – meist viele Stunden im Flugzeug.", items: [
                "Nackenkissen", "Beutel für Flüssigkeiten (100 ml)", "Kompressionsstrümpfe", "Schlafmaske & Ohrstöpsel", "Snacks",
            ]))
        }
        if tropics {
            out.append(PackPackage(id: "tropen", title: "Tropen", reason: "Starke Sonne, Mücken, ungewohntes Essen.", items: [
                "Mückenschutz", "Sonnencreme LSF 50", "Reiseapotheke (Durchfall, Elektrolyte)", "Impfpass", "Desinfektionsgel",
            ]))
        }

        // Wetter
        if let c = climate {
            if c.max >= 24 || tropics {
                out.append(PackPackage(id: "warm", title: "Warm", reason: "Meist um \(Int(c.max.rounded()))° tagsüber.", items: [
                    "Sonnencreme", "Sonnenbrille", "Kappe / Hut", "Kurze Hosen", "Sandalen / Flip-Flops", "Leichte Kleidung",
                ]))
            } else if c.max <= 8 {
                out.append(PackPackage(id: "kalt", title: "Kalt", reason: "Meist nur \(Int(c.max.rounded()))° tagsüber, nachts \(Int(c.min.rounded()))°.", items: [
                    "Winterjacke", "Mütze", "Schal", "Handschuhe", "Thermounterwäsche", "Lippenpflege", "Warme Schuhe",
                ]))
            } else {
                out.append(PackPackage(id: "mild", title: "Mild", reason: "Tagsüber um \(Int(c.max.rounded()))°, abends kühler.", items: [
                    "Pulli", "Leichte Jacke", "Lange Hose",
                ]))
            }
            if c.wetShare >= 0.3 {
                out.append(PackPackage(id: "regen", title: "Regen", reason: "Regen an etwa \(Int((c.wetShare * 100).rounded())) % der Tage.", items: [
                    "Regenjacke", "Taschenschirm", "Wasserfeste Schuhe",
                ]))
            }
        }

        // Dauer
        if nights >= 7 {
            out.append(PackPackage(id: "lang", title: "Länger unterwegs", reason: "\(nights) Nächte – Wäsche unterwegs spart Platz.", items: [
                "Reisewaschmittel", "Wäschebeutel", "Nagelknipser", "Ersatz-Ladekabel",
            ]))
        }

        // Reiseart
        switch kind {
        case .stadt?:
            out.append(PackPackage(id: "stadt", title: "Städtetrip", reason: "Viel zu Fuß unterwegs.", items: ["Bequeme Schuhe", "Kleiner Rucksack", "Trinkflasche", "Schickeres Outfit für abends"]))
        case .strand?:
            out.append(PackPackage(id: "strand", title: "Strand", reason: "Wasser, Sand und Sonne.", items: ["Badesachen", "Strandtuch", "Sonnencreme", "Flip-Flops", "Wasserdichte Handyhülle", "After-Sun"]))
        case .ski?:
            out.append(PackPackage(id: "ski", title: "Ski", reason: "Für die Piste.", items: ["Skihelm", "Skibrille", "Skihandschuhe", "Skiunterwäsche", "Skisocken", "Skipass / Buchung", "Lippenpflege mit LSF"]))
        case .wandern?:
            out.append(PackPackage(id: "wandern", title: "Wandern", reason: "Lange Strecken im Gelände.", items: ["Wanderschuhe", "Wanderrucksack", "Trinkflasche", "Blasenpflaster", "Funktionsshirts", "Regenjacke", "Stirnlampe"]))
        case .business?:
            out.append(PackPackage(id: "business", title: "Geschäftlich", reason: "Termine vor Ort.", items: ["Laptop & Ladegerät", "Hemd / Bluse", "Blazer", "Schuhe fürs Büro", "Unterlagen"]))
        case nil:
            break
        }
        return out
    }

    /// Vergleich ohne Mengen und Groß/Klein („T-Shirts × 5“ = „t-shirts“)
    static func key(_ s: String) -> String {
        var t = s.lowercased()
        if let i = t.range(of: " × ") { t = String(t[..<i.lowerBound]) }
        if let i = t.firstIndex(of: "(") { t = String(t[..<i]) }
        return t.trimmingCharacters(in: .whitespaces)
    }
}

/// Vorschläge ansehen, abwählen, übernehmen
struct PackPlanSheet: View {
    let trip: ReiseBucket.Trip
    let days: [TripWeatherDay]
    let onAdd: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var off: Set<String> = []

    private var packages: [PackPackage] {
        let have = Set(trip.pack.map { PackPlanner.key($0.t) })
        var seen = have
        return PackPlanner.packages(kind: TripKind(rawValue: trip.kind), country: trip.cc, lat: trip.lat,
                                    nights: trip.nights, climate: PackPlanner.climate(days))
            .map { p in
                PackPackage(id: p.id, title: p.title, reason: p.reason, items: p.items.filter { seen.insert(PackPlanner.key($0)).inserted })
            }
            .filter { !$0.items.isEmpty }
    }

    var body: some View {
        let list = packages
        let chosen = list.flatMap(\.items).filter { !off.contains($0) }
        NavigationView {
            List {
                if !trip.hasPlace || days.isEmpty || TripKind(rawValue: trip.kind) == nil {
                    Section {
                        Text(hint).font(.subheadline).foregroundColor(Theme.secondary)
                    }
                }
                ForEach(list) { p in
                    Section {
                        ForEach(p.items, id: \.self) { item in
                            Button {
                                if off.contains(item) { off.remove(item) } else { off.insert(item) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: off.contains(item) ? "circle" : "checkmark.circle.fill")
                                        .font(.title3).foregroundColor(off.contains(item) ? Theme.secondary : Theme.accent)
                                    Text(item).foregroundColor(.primary)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: { Text(p.title) } footer: { Text(p.reason) }
                }
                if list.isEmpty {
                    Section { Text("Alles Vorgeschlagene steht schon in deiner Packliste.").foregroundColor(Theme.secondary) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Packliste für " + trip.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen (\(chosen.count))") { onAdd(chosen); dismiss() }.disabled(chosen.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var hint: String {
        var parts: [String] = []
        if !trip.hasPlace { parts.append("ein Ziel") }
        if TripKind(rawValue: trip.kind) == nil { parts.append("die Art der Reise") }
        if parts.isEmpty { return "Das Wetter am Ziel lädt noch – die Vorschläge zum Wetter kommen dann dazu." }
        return "Tipp: Trag unter „Bearbeiten“ " + parts.joined(separator: " und ") + " ein, dann passen die Vorschläge besser."
    }
}
