import SwiftUI
import Combine
import AudioToolbox
import UserNotifications
import AVFoundation
import UIKit

// ============================================================
// Wecker (Bucket „Uhr“) – Design: docs/specs/2026-11-24-uhr-wecker-design.md
//
// Ein Wecker gehört zum Haushalt (Tabelle `alarms`). Jedes Gerät rechnet selbst aus,
// ob gerade geklingelt wird. Beenden/Schlummern wird im Wecker gespeichert
// (dismissed_for / snooze_for + snooze_until) und gilt damit auf allen Geräten.
//   - In Hubert: großer Wecker-Bildschirm mit Ton, bis beendet (höchstens 30 min).
//   - App zu: iOS-Mitteilung zur Weckzeit (bzw. Schlummer-Ende), auf diesem Gerät geplant.
// ============================================================

struct Alarm: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var household_id: String
    var owner: String
    var shared: Bool = true
    var name: String = ""
    var hour: Int = 7
    var minute: Int = 0
    var days: [Int] = []          // 1 = Mo … 7 = So; leer = einmalig
    var enabled: Bool = true
    var armed_at: String = ISO.string(Date())
    var snooze_min: Int = 9
    var sound: String = "standard"
    var ramp: Bool = true
    var lamps: [String] = []
    var light_lead: Int = 0
    var light_stagger: Bool = false
    var dismissed_for: String?
    var snooze_for: String?
    var snooze_until: String?
    var position: Int = 0
    var dismissed_by: String?

    enum CodingKeys: String, CodingKey {
        case id, household_id, owner, shared, name, hour, minute, days, enabled, armed_at, snooze_min, sound, ramp
        case lamps, light_lead, light_stagger, dismissed_for, snooze_for, snooze_until, position, dismissed_by
    }

    // Leere Felder ausdrücklich als null senden (sonst bliebe ein altes Schlummern auf dem Server stehen)
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(household_id, forKey: .household_id); try c.encode(owner, forKey: .owner)
        try c.encode(shared, forKey: .shared); try c.encode(name, forKey: .name)
        try c.encode(hour, forKey: .hour); try c.encode(minute, forKey: .minute); try c.encode(days, forKey: .days)
        try c.encode(enabled, forKey: .enabled); try c.encode(armed_at, forKey: .armed_at)
        try c.encode(snooze_min, forKey: .snooze_min); try c.encode(sound, forKey: .sound); try c.encode(ramp, forKey: .ramp)
        try c.encode(lamps, forKey: .lamps); try c.encode(light_lead, forKey: .light_lead); try c.encode(light_stagger, forKey: .light_stagger)
        try c.encode(dismissed_for, forKey: .dismissed_for); try c.encode(snooze_for, forKey: .snooze_for)
        try c.encode(snooze_until, forKey: .snooze_until); try c.encode(position, forKey: .position)
        try c.encodeIfPresent(dismissed_by, forKey: .dismissed_by)
    }

    var timeText: String { String(format: "%d:%02d", hour, minute) }
    var title: String { name.isEmpty ? "Wecker" : name }

    var armed: Date { ISO.date(armed_at) ?? .distantPast }
    var dismissedFor: Date? { dismissed_for.flatMap(ISO.date) }
    var snoozeFor: Date? { snooze_for.flatMap(ISO.date) }
    var snoozeUntil: Date? { snooze_until.flatMap(ISO.date) }

    /// Wochentag nach Kalender (1 = So … 7 = Sa) → unsere Zählung (1 = Mo … 7 = So)
    static func ourDay(_ weekday: Int) -> Int { weekday == 1 ? 7 : weekday - 1 }

    /// Alle planmäßigen Weckzeiten im Zeitraum (nach dem Scharfstellen)
    func fires(from: Date, to: Date) -> [Date] {
        guard enabled else { return [] }
        let cal = Calendar.current
        var out: [Date] = []
        var day = cal.startOfDay(for: from)
        while day <= to {
            if let d = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day),
               d >= from, d <= to, d > armed,
               days.isEmpty || days.contains(Self.ourDay(cal.component(.weekday, from: day))) {
                out.append(d)
                if days.isEmpty { break }          // einmalig: nur das erste Mal nach dem Scharfstellen
            }
            guard let n = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = n
        }
        return out
    }

    /// Nächste Weckzeit, die noch kommt (übersprungene ausgelassen)
    func nextFire(after now: Date = Date()) -> Date? {
        fires(from: now, to: now.addingTimeInterval(8 * 86400)).first { $0 != dismissedFor }
    }

    /// Kurzbeschreibung der Tage: „Mo–Fr“, „Wochenende“, „Täglich“, „Einmal“, „Mo, Mi, Fr“
    var daysText: String {
        let d = Set(days)
        if d.isEmpty { return "Einmal" }
        if d.count == 7 { return "Täglich" }
        if d == [1, 2, 3, 4, 5] { return "Mo–Fr" }
        if d == [6, 7] { return "Wochenende" }
        let names = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        return d.sorted().map { names[$0 - 1] }.joined(separator: ", ")
    }
}

/// Ein klingelnder Wecker mit seiner Weckzeit (für Beenden/Schlummern)
struct RingingAlarm: Equatable {
    let alarm: Alarm
    let fire: Date
}

final class AlarmCenter: ObservableObject {
    static let shared = AlarmCenter()

    @Published private(set) var alarms: [Alarm] = []
    @Published private(set) var ringing: RingingAlarm?
    @Published private(set) var loaded = false

    private let api = SupabaseClient.shared
    private var household: String?
    private var clock: AnyCancellable?
    private var lastBeep = Date.distantPast
    private var ringStarted = Date.distantPast
    private var kitTrimmed = false
    private let cacheKey = "alarms.cache"
    /// So lange klingelt ein Wecker höchstens, dann hört er von allein auf
    static let maxRing: TimeInterval = 30 * 60

    init() {
        if let d = UserDefaults.standard.data(forKey: cacheKey),
           let list = try? JSONDecoder().decode([Alarm].self, from: d) { alarms = list }
        clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] now in
            Task { @MainActor in self?.step(now) }
        }
    }

    var userId: String? { api.userId }

    /// Klingelt dieser Wecker auf diesem Gerät? (Haushalt = überall, sonst nur beim Besitzer)
    func ringsHere(_ a: Alarm) -> Bool { a.shared || a.owner == userId }

    var sorted: [Alarm] {
        alarms.sorted { ($0.hour, $0.minute, $0.name) < ($1.hour, $1.minute, $1.name) }
    }

    /// Nächster Wecker, der auf diesem Gerät klingelt
    var next: (alarm: Alarm, fire: Date)? {
        alarms.filter(ringsHere).compactMap { a in a.nextFire().map { (a, $0) } }.min { $0.1 < $1.1 }
    }

    // MARK: Abgleich

    func apply(remote rows: [Alarm], household h: String) {
        household = h
        loaded = true
        if rows != alarms {
            alarms = rows
            cache()
        }
        reschedule()
        step(Date())
    }

    func load(household h: String) async {
        household = h
        if let rows: [Alarm] = try? await api.select("alarms", ["household_id": "eq." + h, "order": "hour,minute"]) {
            apply(remote: rows, household: h)
        }
    }

    // MARK: Ändern

    func newAlarm() -> Alarm? {
        guard let h = household ?? TimerCenter.shared.household, let uid = userId else { return nil }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date().addingTimeInterval(3600))
        return Alarm(household_id: h, owner: uid, hour: now.hour ?? 7, minute: 0)
    }

    /// Speichern (neu oder geändert). Zeit/Tage geändert oder neu eingeschaltet → neu scharfstellen.
    func save(_ a: Alarm) {
        var a = a
        if let old = alarms.first(where: { $0.id == a.id }) {
            if old.hour != a.hour || old.minute != a.minute || old.days != a.days || (!old.enabled && a.enabled) {
                rearm(&a)
            }
        } else {
            rearm(&a)
        }
        upsertLocal(a)
        push(a)
    }

    func toggle(_ a: Alarm, on: Bool) {
        var a = a
        a.enabled = on
        if on { rearm(&a) }
        upsertLocal(a)
        push(a)
    }

    func delete(_ a: Alarm) {
        alarms.removeAll { $0.id == a.id }
        cache(); reschedule()
        Task { try? await self.api.delete("alarms", ["id": "eq." + a.id]) }
    }

    /// Nächstes Klingeln auslassen (z. B. „morgen frei“) – bzw. wieder zulassen
    func skipNext(_ a: Alarm, _ skip: Bool) {
        var a = a
        if skip, let f = a.fires(from: Date(), to: Date().addingTimeInterval(8 * 86400)).first {
            a.dismissed_for = ISO.string(f)
        } else if !skip {
            a.dismissed_for = nil
        }
        upsertLocal(a)
        push(a)
    }

    func isSkipped(_ a: Alarm) -> Bool {
        guard let d = a.dismissedFor else { return false }
        return d > Date() && a.fires(from: Date(), to: Date().addingTimeInterval(8 * 86400)).first == d
    }

    /// Klingeln beenden – überall. Einmal-Wecker schalten sich danach ab.
    func dismiss() {
        guard !justStarted else { return }
        guard let r = ringing, var a = alarms.first(where: { $0.id == r.alarm.id }) else { ringing = nil; return }
        a.dismissed_for = ISO.string(r.fire)
        a.dismissed_by = AppStore.deviceName + " " + String(Device.id.prefix(6))
        a.snooze_for = nil; a.snooze_until = nil
        if a.days.isEmpty { a.enabled = false }
        ringing = nil
        upsertLocal(a)
        push(a)
    }

    /// Schlummern – überall
    func snooze() {
        guard !justStarted else { return }
        guard let r = ringing, var a = alarms.first(where: { $0.id == r.alarm.id }) else { ringing = nil; return }
        a.snooze_for = ISO.string(r.fire)
        a.snooze_until = ISO.string(Date().addingTimeInterval(TimeInterval(max(1, a.snooze_min) * 60)))
        ringing = nil
        upsertLocal(a)
        push(a)
    }

    private func rearm(_ a: inout Alarm) {
        a.armed_at = ISO.string(Date())
        a.dismissed_for = nil; a.snooze_for = nil; a.snooze_until = nil
    }

    private func upsertLocal(_ a: Alarm) {
        if let i = alarms.firstIndex(where: { $0.id == a.id }) { alarms[i] = a } else { alarms.append(a) }
        cache(); reschedule(); step(Date())
    }

    private func push(_ a: Alarm) {
        let row = a
        Task { try? await self.api.upsert("alarms", [row]) }
    }

    private func cache() {
        if let d = try? JSONEncoder().encode(alarms) { UserDefaults.standard.set(d, forKey: cacheKey) }
    }

    // MARK: Klingeln

    /// Welche Weckzeit gerade klingelt (nil = keine)
    private func current(_ a: Alarm, now: Date) -> RingingAlarm? {
        guard ringsHere(a) else { return nil }
        // letzte planmäßige Weckzeit der vergangenen Stunden
        guard let fire = a.fires(from: now.addingTimeInterval(-6 * 3600), to: now).last else {
            // Einmal-Wecker, der schon beendet wurde, ist abgeschaltet → nichts
            return nil
        }
        if a.dismissedFor == fire { return nil }
        var start = fire
        if a.snoozeFor == fire, let until = a.snoozeUntil {
            if until > now { return nil }        // schlummert noch
            start = until
        }
        guard now.timeIntervalSince(start) < Self.maxRing else { return nil }
        return RingingAlarm(alarm: a, fire: fire)
    }

    private func step(_ now: Date) {
        // Einmal-Wecker nach dem Klingeln: Abschalten übernimmt dismiss(); hier nur anzeigen
        let found = alarms.compactMap { current($0, now: now) }.min { $0.fire < $1.fire }
        if found != ringing {
            if ringing == nil, found != nil { ringStarted = now }
            ringing = found
        }
        // Licht (nur das Lichtgerät schaltet, nur wenn es Lampen gibt)
        if LightHost.shared.isHost && LightHost.hasLights { lightStep(now) }
        // Hubert offen und eine Weckzeit steht in der nächsten Minute an → System-Wecker dafür zurücknehmen
        if AlarmKitBridge.available && UIApplication.shared.applicationState == .active {
            let soon = alarms.filter(ringsHere).contains { a in
                a.fires(from: now, to: now.addingTimeInterval(60)).contains { $0 != a.dismissedFor } ||
                (a.snoozeUntil.map { $0 > now && $0 <= now.addingTimeInterval(60) } ?? false)
            }
            if soon && !kitTrimmed { kitTrimmed = true; reschedule() }
            if !soon { kitTrimmed = false }
            if ringing != nil { AlarmKitBridge.silenceAlerting() }
        }
        // Ton und Wecker-Fenster folgen dem Klingeln
        if let r = ringing {
            AlarmSound.shared.start(tone: AlarmTone.from(r.alarm.sound), ramp: r.alarm.ramp)
            AlarmWindow.shared.show()
        } else if AlarmWindow.shared.visible {
            AlarmSound.shared.stop()
            AlarmWindow.shared.hide()
        }
    }

    /// Schutz vor einem versehentlichen Tipp genau in dem Moment, in dem der Wecker erscheint
    var justStarted: Bool { Date().timeIntervalSince(ringStarted) < 1.5 }

    // MARK: Licht beim Wecker

    /// Erledigte Licht-Schritte (Schlüssel → Zeitpunkt), damit nichts doppelt schaltet – auch nach Neustart
    private var lightDone: [String: Double] = (UserDefaults.standard.dictionary(forKey: "alarms.lightDone") as? [String: Double]) ?? [:]

    private func once(_ key: String, _ action: () -> Void) {
        guard lightDone[key] == nil else { return }
        lightDone[key] = Date().timeIntervalSince1970
        let cutoff = Date().timeIntervalSince1970 - 2 * 86400
        lightDone = lightDone.filter { $0.value > cutoff }
        UserDefaults.standard.set(lightDone, forKey: "alarms.lightDone")
        action()
    }

    /// Plan pro Weckzeit F (Vorlauf L Minuten, n Lampen):
    ///   ohne Vorlauf: alle Lampen bei F an
    ///   mit Vorlauf: alle bei F − L an – oder „nacheinander“ gleichmäßig verteilt zwischen F − L und F
    ///   Schlummern: Lampen aus, am Ende des Schlummerns wieder an. Beenden: Licht bleibt an.
    /// Ein Schritt wird nur ausgeführt, wenn sein Zeitpunkt höchstens 2 Minuten zurückliegt.
    private func lightStep(_ now: Date) {
        let available = Set(SmartHomeStore.shared.lights.map(\.id))
        for a in alarms where a.enabled || a.snoozeFor != nil {
            let lamps = a.lamps.filter { available.contains($0) }
            guard !lamps.isEmpty else { continue }
            let lead = TimeInterval(max(0, a.light_lead) * 60)
            for f in a.fires(from: now.addingTimeInterval(-2 * 3600), to: now.addingTimeInterval(lead + 60)) {
                if a.dismissedFor == f && a.snoozeFor != f && f > now { continue }   // übersprungen
                let base = a.id + "|" + String(Int(f.timeIntervalSince1970))
                // Einschalten vor bzw. bei der Weckzeit
                if a.dismissedFor != f || now >= f {
                    let steps: [(Date, [String])]
                    if lead > 0 && a.light_stagger && lamps.count > 1 {
                        let gap = lead / Double(lamps.count)
                        steps = lamps.enumerated().map { (f.addingTimeInterval(-lead + Double($0.offset) * gap), [$0.element]) }
                    } else {
                        steps = [(f.addingTimeInterval(-lead), lamps)]
                    }
                    for (i, st) in steps.enumerated() where now >= st.0 && now.timeIntervalSince(st.0) < 120 {
                        once(base + "|on\(i)") { SmartHomeStore.shared.switchLights(st.1, on: true) }
                    }
                }
                // Schlummern: aus – und am Ende wieder an
                if a.snoozeFor == f, let until = a.snoozeUntil {
                    let key = base + "|" + String(Int(until.timeIntervalSince1970))
                    if now < until { once(key + "|off") { SmartHomeStore.shared.switchLights(lamps, on: false) } }
                    else if now.timeIntervalSince(until) < 120 { once(key + "|on") { SmartHomeStore.shared.switchLights(lamps, on: true) } }
                }
            }
        }
    }

    // MARK: Mitteilungen (falls Hubert zu ist)

    private static let prefix = "alarm."

    /// Mitteilungen dieses Geräts neu planen: die nächsten Weckzeiten (max. 40) plus laufendes Schlummern
    func reschedule() {
        let c = UNUserNotificationCenter.current()
        let mine = alarms.filter(ringsHere)
        let now = Date()
        let active = UIApplication.shared.applicationState == .active
        var plan: [(Alarm, Date)] = []
        for a in mine {
            for f in a.fires(from: now, to: now.addingTimeInterval(4 * 86400)) where f != a.dismissedFor {
                plan.append((a, f))
            }
            if let s = a.snoozeUntil, s > now, a.snoozeFor != a.dismissedFor { plan.append((a, s)) }
        }
        plan.sort { $0.1 < $1.1 }
        // Hubert geht gerade in den Hintergrund und klingelt: als System-Wecker gleich weiterklingeln
        if !active, let r = ringing { plan.insert((r.alarm, now.addingTimeInterval(3)), at: 0) }

        // System-Wecker (ab iOS 26): Ist Hubert offen, klingelt Hubert die nächste Minute selbst
        let kit = plan.filter { !active || $0.1 > now.addingTimeInterval(60) }.prefix(30)
            .map { PlannedRing(alarmId: $0.0.id, title: $0.0.title, fire: $0.1) }
        let useKit = AlarmKitBridge.available
        AlarmTone.installNotificationSounds()
        Task {
            if useKit { await AlarmKitBridge.sync(Array(kit)) }
            let kitOn = useKit && AlarmKitBridge.authorized
            if !mine.isEmpty && !kitOn { _ = try? await c.requestAuthorization(options: [.alert, .sound]) }
            let pending = await c.pendingNotificationRequests()
            c.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) })
            guard !kitOn else { return }      // System-Wecker übernehmen – keine doppelten Mitteilungen

            for (a, d) in plan.prefix(40) {
                let content = UNMutableNotificationContent()
                content.title = "⏰ " + a.title
                content.body = String(format: "%d:%02d – Wecker", Calendar.current.component(.hour, from: d), Calendar.current.component(.minute, from: d))
                content.sound = AlarmTone.from(a.sound).notificationSound
                content.interruptionLevel = .timeSensitive
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let id = Self.prefix + a.id + "." + String(Int(d.timeIntervalSince1970))
                try? await c.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    // MARK: Vom Sperrbildschirm (AlarmKit, ab iOS 26)

    /// „Beenden“ am System-Wecker
    func systemStop(alarmId: String, fire: Date) async {
        if alarms.isEmpty, let h = household ?? TimerCenter.shared.household { await load(household: h) }
        guard var a = alarms.first(where: { $0.id == alarmId }) else { return }
        // Bei einem Schlummer-Klingeln ist „fire“ das Schlummer-Ende – gemeint ist die ursprüngliche Weckzeit
        let original = a.snoozeUntil == fire ? (a.snoozeFor ?? fire) : fire
        a.dismissed_for = ISO.string(original)
        a.dismissed_by = AppStore.deviceName + " (Sperrbildschirm)"
        a.snooze_for = nil; a.snooze_until = nil
        if a.days.isEmpty { a.enabled = false }
        if let i = alarms.firstIndex(where: { $0.id == a.id }) { alarms[i] = a }
        cache()
        try? await api.upsert("alarms", [a])      // abwarten: die App läuft hier evtl. nur kurz im Hintergrund
        reschedule()
    }

    /// „Schlummern“ am System-Wecker
    func systemSnooze(alarmId: String, fire: Date) async {
        if alarms.isEmpty, let h = household ?? TimerCenter.shared.household { await load(household: h) }
        guard var a = alarms.first(where: { $0.id == alarmId }) else { return }
        let original = a.snoozeUntil == fire ? (a.snoozeFor ?? fire) : fire
        a.snooze_for = ISO.string(original)
        a.snooze_until = ISO.string(Date().addingTimeInterval(TimeInterval(max(1, a.snooze_min) * 60)))
        if let i = alarms.firstIndex(where: { $0.id == a.id }) { alarms[i] = a }
        cache()
        try? await api.upsert("alarms", [a])
        reschedule()
    }
}

// MARK: Ton
// Warum nicht der System-Ton (AudioServicesPlayAlertSound): Der bleibt stumm, wenn das Gerät
// auf „Stumm“ steht – genau das war „der Wecker hat nicht geläutet“. AVAudioPlayer mit der
// Kategorie .playback klingt auch im Stumm-Modus (Lautstärke = Medienlautstärke).

final class AlarmSound {
    static let shared = AlarmSound()
    private var player: AVAudioPlayer?
    private var started = Date.distantPast
    private var rampTimer: Timer?
    private var previewStop: DispatchWorkItem?
    private(set) var playingTone: AlarmTone?

    /// Wecker klingelt: Ton in Schleife, auf Wunsch langsam lauter (30 s)
    func start(tone: AlarmTone, ramp: Bool) {
        if playingTone == tone && previewStop == nil { return }
        stop()
        play(tone, volume: ramp ? 0.15 : 1)
        started = Date()
        if ramp {
            rampTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
                DispatchQueue.main.async {
                    guard let self = self, let p = self.player else { t.invalidate(); return }
                    let f = min(1, Date().timeIntervalSince(self.started) / 30)
                    p.volume = Float(0.15 + 0.85 * f)
                    if f >= 1 { t.invalidate() }
                }
            }
        }
    }

    /// Kurz vorspielen (beim Auswählen im Wecker), 3 s
    func preview(_ tone: AlarmTone) {
        stop()
        play(tone, volume: 0.8)
        let w = DispatchWorkItem { [weak self] in self?.stop() }
        previewStop = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    private func play(_ tone: AlarmTone, volume: Float) {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? s.setActive(true)
        guard let p = try? AVAudioPlayer(data: tone.wav()) else { return }
        p.numberOfLoops = -1
        p.volume = volume
        p.play()
        player = p
        playingTone = tone
    }

    func stop() {
        previewStop?.cancel(); previewStop = nil
        guard player != nil else { return }
        rampTimer?.invalidate(); rampTimer = nil
        player?.stop(); player = nil
        playingTone = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

// MARK: Eigenes Fenster über allem
// Warum: Ein .overlay an der App liegt UNTER Blättern (z. B. der geöffneten Uhr-App).
// Der Wecker muss aber immer obenauf sein – darum ein eigenes Fenster auf Alarm-Ebene.

final class AlarmWindow {
    static let shared = AlarmWindow()
    private var window: UIWindow?

    func show() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ??
                UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        let host = UIHostingController(rootView: AlarmRingOverlay())
        host.view.backgroundColor = .clear
        w.rootViewController = host
        w.overrideUserInterfaceStyle = .dark
        w.makeKeyAndVisible()
        window = w
    }

    var visible: Bool { window != nil }

    func hide() {
        guard let w = window else { return }
        w.isHidden = true
        window = nil
    }
}

// MARK: Wecker-Bildschirm (im eigenen Fenster über allem)

struct AlarmRingOverlay: View {
    @ObservedObject private var center = AlarmCenter.shared
    @Environment(\.horizontalSizeClass) private var size

    var body: some View {
        if let r = center.ringing {
            let big = size == .regular
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: big ? 28 : 18) {
                    Spacer()
                    Image(systemName: "alarm.fill").font(.system(size: big ? 56 : 40)).foregroundColor(Theme.accent)
                    Text(r.alarm.timeText)
                        .font(.system(size: big ? 140 : 88, weight: .thin).monospacedDigit())
                        .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.5)
                    Text(r.alarm.title).font(big ? .title : .title2).foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center).lineLimit(2)
                    Spacer()
                    VStack(spacing: 14) {
                        Button { center.snooze() } label: {
                            Text("Schlummern · \(r.alarm.snooze_min) Min.").font(.title3.weight(.semibold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: big ? 88 : 64)
                                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.16)))
                        }
                        Button { center.dismiss() } label: {
                            Text("Beenden").font(.title3.weight(.semibold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: big ? 88 : 64)
                                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.accent))
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 520)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, big ? 48 : 24)
            }
            .transition(.opacity)
        }
    }
}
