import Foundation
import SwiftUI
import CryptoKit
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
#endif

// ============================================================
// Echter System-Wecker über AlarmKit (ab iOS/iPadOS 26).
// Warum: Eine gesperrte App darf sonst nur Mitteilungen schicken (30 s, stumm bei „Stumm“/Fokus).
// AlarmKit klingelt wie Apples Uhr-App – auch gesperrt, im Stumm-Modus und bei Fokus.
//
// Aufteilung:
//   - Hubert offen  → Hubert klingelt selbst (Ton langsam lauter, Licht, eigener Bildschirm);
//                     anstehende AlarmKit-Wecker der nächsten Minute werden dafür zurückgenommen.
//   - Hubert zu/gesperrt → AlarmKit klingelt. „Beenden“/„Schlummern“ dort laufen über
//                     App-Intents in Hubert und gelten damit auf allen Geräten.
// Grenzen: Wegwischen auf dem Sperrbildschirm meldet AlarmKit der App nicht.
// Ältere Geräte (iOS < 26) bekommen weiterhin Mitteilungen.
// ============================================================

/// Ein geplantes Klingeln (unabhängig vom AlarmKit-Typ „Alarm“)
struct PlannedRing: Hashable {
    let alarmId: String
    let title: String
    let fire: Date
}

enum AlarmKitBridge {
    /// Gibt es AlarmKit auf diesem Gerät?
    static var available: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// Darf Hubert System-Wecker stellen? (Dann keine Mitteilungen für Wecker)
    static var authorized: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return AlarmManager.shared.authorizationState == .authorized }
        #endif
        return false
    }

    /// Feste Kennung je Wecker und Weckzeit (gleich auf jedem Durchlauf → nichts doppelt)
    static func uuid(_ alarmId: String, _ fire: Date) -> UUID {
        let h = Array(SHA256.hash(data: Data("\(alarmId)|\(Int(fire.timeIntervalSince1970))".utf8)))
        return UUID(uuid: (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8], h[9], h[10], h[11], h[12], h[13], h[14], h[15]))
    }

    /// Geplante System-Wecker an den Plan angleichen (fehlende anlegen, überflüssige löschen)
    static func sync(_ plan: [PlannedRing]) async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { await syncNow(plan) }
        #endif
    }

    /// Hubert ist offen und klingelt selbst: laufende System-Wecker stummschalten
    static func silenceAlerting() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let m = AlarmManager.shared
            for a in (try? m.alarms) ?? [] where a.state == .alerting {
                try? m.stop(id: a.id)
            }
        }
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func syncNow(_ plan: [PlannedRing]) async {
        let m = AlarmManager.shared
        var state = m.authorizationState
        if state == .notDetermined && !plan.isEmpty {
            state = (try? await m.requestAuthorization()) ?? .denied
        }
        guard state == .authorized else { return }

        var wanted: [UUID: PlannedRing] = [:]
        for p in plan where p.fire > Date() { wanted[uuid(p.alarmId, p.fire)] = p }
        let existing = (try? m.alarms) ?? []
        for a in existing where wanted[a.id] == nil && a.state != .alerting {
            try? m.cancel(id: a.id)
        }
        let have = Set(existing.map(\.id))
        for (id, p) in wanted where !have.contains(id) {
            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: p.title),
                stopButton: AlarmButton(text: "Beenden", textColor: .white, systemImageName: "stop.fill"),
                secondaryButton: AlarmButton(text: "Schlummern", textColor: .white, systemImageName: "zzz"),
                // .custom statt .countdown: Ein Countdown bräuchte eine Widget-Erweiterung (Live Activity),
                // sonst kann das System Wecker verwerfen. Schlummern plant Hubert selbst neu.
                secondaryButtonBehavior: .custom)
            let attrs = AlarmAttributes<HubertAlarmData>(
                presentation: AlarmPresentation(alert: alert),
                metadata: HubertAlarmData(alarmId: p.alarmId, fire: p.fire.timeIntervalSince1970),
                tintColor: Color(red: 0.91, green: 0.35, blue: 0.05))
            let config = AlarmManager.AlarmConfiguration<HubertAlarmData>(
                countdownDuration: nil,
                schedule: .fixed(p.fire),
                attributes: attrs,
                stopIntent: StopHubertAlarm(alarmId: p.alarmId, fire: p.fire.timeIntervalSince1970),
                secondaryIntent: SnoozeHubertAlarm(alarmId: p.alarmId, fire: p.fire.timeIntervalSince1970))
            _ = try? await m.schedule(id: id, configuration: config)
        }
    }
    #endif
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
nonisolated struct HubertAlarmData: AlarmMetadata {
    var alarmId: String = ""
    var fire: Double = 0
}

/// „Beenden“ auf dem Sperrbildschirm → gilt in Hubert auf allen Geräten
@available(iOS 26.0, *)
nonisolated struct StopHubertAlarm: LiveActivityIntent {
    static let title: LocalizedStringResource = "Wecker beenden"
    @Parameter(title: "Wecker") var alarmId: String
    @Parameter(title: "Weckzeit") var fire: Double

    init() {}
    init(alarmId: String, fire: Double) {
        self.alarmId = alarmId
        self.fire = fire
    }

    func perform() async throws -> some IntentResult {
        await AlarmCenter.shared.systemStop(alarmId: alarmId, fire: Date(timeIntervalSince1970: fire))
        return .result()
    }
}

/// „Schlummern“ auf dem Sperrbildschirm → Hubert plant das nächste Klingeln (auch als System-Wecker)
@available(iOS 26.0, *)
nonisolated struct SnoozeHubertAlarm: LiveActivityIntent {
    static let title: LocalizedStringResource = "Wecker schlummern"
    @Parameter(title: "Wecker") var alarmId: String
    @Parameter(title: "Weckzeit") var fire: Double

    init() {}
    init(alarmId: String, fire: Double) {
        self.alarmId = alarmId
        self.fire = fire
    }

    func perform() async throws -> some IntentResult {
        await AlarmCenter.shared.systemSnooze(alarmId: alarmId, fire: Date(timeIntervalSince1970: fire))
        return .result()
    }
}
#endif
