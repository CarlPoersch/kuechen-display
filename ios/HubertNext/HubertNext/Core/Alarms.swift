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
        // Ton und Wecker-Fenster folgen dem Klingeln
        if let r = ringing {
            AlarmSound.shared.start(ramp: r.alarm.ramp)
            AlarmWindow.shared.show()
        } else {
            AlarmSound.shared.stop()
            AlarmWindow.shared.hide()
        }
    }

    /// Schutz vor einem versehentlichen Tipp genau in dem Moment, in dem der Wecker erscheint
    var justStarted: Bool { Date().timeIntervalSince(ringStarted) < 1.5 }

    // MARK: Mitteilungen (falls Hubert zu ist)

    private static let prefix = "alarm."

    /// Mitteilungen dieses Geräts neu planen: die nächsten Weckzeiten (max. 40) plus laufendes Schlummern
    func reschedule() {
        let c = UNUserNotificationCenter.current()
        let list = alarms
        let mine = list.filter(ringsHere)
        Task {
            if !mine.isEmpty { _ = try? await c.requestAuthorization(options: [.alert, .sound]) }
            let pending = await c.pendingNotificationRequests()
            c.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) })

            let now = Date()
            var plan: [(Alarm, Date)] = []
            for a in mine {
                for f in a.fires(from: now, to: now.addingTimeInterval(4 * 86400)) where f != a.dismissedFor {
                    plan.append((a, f))
                }
                if let s = a.snoozeUntil, s > now, a.snoozeFor != a.dismissedFor { plan.append((a, s)) }
            }
            for (a, d) in plan.sorted(by: { $0.1 < $1.1 }).prefix(40) {
                let content = UNMutableNotificationContent()
                content.title = "⏰ " + a.title
                content.body = String(format: "%d:%02d – Wecker", Calendar.current.component(.hour, from: d), Calendar.current.component(.minute, from: d))
                content.sound = .default
                if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let id = Self.prefix + a.id + "." + String(Int(d.timeIntervalSince1970))
                try? await c.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
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
    private var ramp = true
    private var rampTimer: Timer?

    func start(ramp: Bool) {
        guard player == nil else { return }
        self.ramp = ramp
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? s.setActive(true)
        guard let p = try? AVAudioPlayer(data: Self.tone) else { return }
        p.numberOfLoops = -1
        p.volume = ramp ? 0.15 : 1
        p.play()
        player = p
        started = Date()
        // Langsam lauter: in 30 s auf volle Lautstärke
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

    func stop() {
        guard player != nil else { return }
        rampTimer?.invalidate(); rampTimer = nil
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Wecker-Ton, selbst erzeugt (keine fremde Aufnahme): zweimal kurz piepen, Pause – als WAV
    static let tone: Data = {
        let rate = 44_100
        var samples: [Int16] = []
        func beep(_ secs: Double, _ freq: Double) {
            let n = Int(secs * Double(rate))
            for i in 0..<n {
                let t = Double(i) / Double(rate)
                // weiches Ein-/Ausblenden gegen Knackser
                let env = min(1, min(t, secs - t) / 0.01)
                samples.append(Int16(sin(2 * .pi * freq * t) * env * 0.6 * Double(Int16.max)))
            }
        }
        func pause(_ secs: Double) { samples.append(contentsOf: repeatElement(0, count: Int(secs * Double(rate)))) }
        beep(0.16, 1046); pause(0.08); beep(0.16, 1046); pause(0.08); beep(0.16, 1318); pause(0.7)

        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        let dataLen = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + dataLen); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(dataLen)
        for s in samples { u16(UInt16(bitPattern: s)) }
        return d
    }()
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
