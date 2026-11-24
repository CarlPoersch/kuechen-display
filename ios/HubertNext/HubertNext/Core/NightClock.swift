import SwiftUI
import Combine

// ============================================================
// Nachtuhr (nur auf Wanddisplays): Bildschirm ganz dunkel, große gedimmte Ziffern,
// darunter der nächste Wecker. Startet
//   - automatisch ab einer Uhrzeit (einstellbar, pro Gerät, einmal pro Nacht),
//   - nach „Gute Nacht“ – von jedem Gerät im Haushalt (Tabelle household_night).
// Endet: Antippen, Wecker (bzw. dessen Licht-Vorlauf), Timer klingelt, oder zur „bis“-Uhrzeit.
// ============================================================

final class NightClock: ObservableObject {
    static let shared = NightClock()

    @Published private(set) var active = false
    @Published var autoOn: Bool { didSet { d.set(autoOn, forKey: "night.auto") } }
    @Published var fromMin: Int { didSet { d.set(fromMin, forKey: "night.from") } }
    @Published var toMin: Int { didSet { d.set(toMin, forKey: "night.to") } }

    private let d = UserDefaults.standard
    private var savedBrightness: CGFloat?
    private var wakeAt = Date.distantFuture
    private var lastRemote: Date
    private var clock: AnyCancellable?

    private var lastAutoNight: String {
        get { d.string(forKey: "night.lastAuto") ?? "" }
        set { d.set(newValue, forKey: "night.lastAuto") }
    }

    init() {
        autoOn = (d.object(forKey: "night.auto") as? Bool) ?? true
        fromMin = (d.object(forKey: "night.from") as? Int) ?? 23 * 60
        toMin = (d.object(forKey: "night.to") as? Int) ?? 6 * 60 + 30
        lastRemote = Date(timeIntervalSince1970: d.double(forKey: "night.lastRemote"))
        clock = Timer.publish(every: 15, on: .main, in: .common).autoconnect().sink { now in
            Task { @MainActor in NightClock.shared.check(now) }
        }
    }

    /// Minuten-Werte als Datum (für DatePicker)
    func binding(_ key: ReferenceWritableKeyPath<NightClock, Int>) -> Binding<Date> {
        Binding(get: {
            let m = self[keyPath: key]
            return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
        }, set: { v in
            let c = Calendar.current.dateComponents([.hour, .minute], from: v)
            self[keyPath: key] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        })
    }

    // MARK: Ablauf

    func check(_ now: Date = Date()) {
        guard LightHost.shared.isWall else { if active { end() }; return }
        if active {
            if shouldWake(now) { end() }
            return
        }
        // Automatisch: einmal pro Nacht, nur im Zeitfenster und nicht kurz vor einem Wecker
        if autoOn && inWindow(now) && lastAutoNight != nightKey(now) && !shouldWake(now) {
            lastAutoNight = nightKey(now)
            start()
        }
    }

    /// „Gute Nacht“: auf allen Wanddisplays des Haushalts (dieses Gerät sofort)
    func request(household: String?) {
        if LightHost.shared.isWall { lastAutoNight = nightKey(Date()); start() }
        guard let h = household else { return }
        struct Row: Encodable { let household_id: String; let requested_at: String; let device: String }
        let row = Row(household_id: h, requested_at: ISO.string(Date()), device: Device.id)
        Task { try? await SupabaseClient.shared.upsert("household_night", [row]) }
    }

    /// Aus dem Live-Abgleich: hat ein anderes Gerät „Gute Nacht“ gedrückt?
    func remote(requestedAt: Date, device: String) {
        guard requestedAt > lastRemote else { return }
        lastRemote = requestedAt
        d.set(requestedAt.timeIntervalSince1970, forKey: "night.lastRemote")
        guard device != Device.id, Date().timeIntervalSince(requestedAt) < 180, LightHost.shared.isWall else { return }
        lastAutoNight = nightKey(Date())
        start()
    }

    func start() {
        guard !active else { return }
        savedBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 0.01
        wakeAt = nextTime(toMin, after: Date())
        withAnimation(.easeInOut(duration: 0.6)) { active = true }
    }

    func end() {
        guard active else { return }
        UIScreen.main.brightness = max(savedBrightness ?? 0.6, 0.3)
        savedBrightness = nil
        withAnimation(.easeInOut(duration: 0.4)) { active = false }
    }

    /// Wach werden: Wecker klingelt oder sein Licht-Vorlauf beginnt, Timer klingelt, „bis“-Uhrzeit erreicht
    private func shouldWake(_ now: Date) -> Bool {
        if AlarmCenter.shared.ringing != nil || !TimerCenter.shared.ringing.isEmpty { return true }
        if active && now >= wakeAt { return true }
        let lights = LightHost.hasLights
        for a in AlarmCenter.shared.alarms {
            let lead = lights && !a.lamps.isEmpty ? TimeInterval(a.light_lead * 60) : 0
            if let f = a.nextFire(after: now.addingTimeInterval(-60)), f.addingTimeInterval(-lead - 60) <= now, now <= f.addingTimeInterval(60) {
                return true
            }
        }
        return false
    }

    private func minuteOfDay(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func inWindow(_ now: Date) -> Bool {
        let m = minuteOfDay(now)
        return fromMin > toMin ? (m >= fromMin || m < toMin) : (m >= fromMin && m < toMin)
    }

    /// Kennung der Nacht (Datum des Abends), damit die Automatik pro Nacht nur einmal startet
    private func nightKey(_ now: Date) -> String {
        let day = minuteOfDay(now) < toMin ? now.addingTimeInterval(-86400) : now
        let c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func nextTime(_ minutes: Int, after d: Date) -> Date {
        let cal = Calendar.current
        let today = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: d) ?? d
        return today > d ? today : (cal.date(byAdding: .day, value: 1, to: today) ?? today)
    }
}

/// Die Nachtuhr selbst (liegt über der Startseite, unter Wecker und Timer-Hinweisen)
struct NightClockOverlay: View {
    @ObservedObject private var night = NightClock.shared
    @ObservedObject private var alarms = AlarmCenter.shared

    var body: some View {
        if night.active {
            TimelineView(.everyMinute) { ctx in
                let f = DateFormatter.nightClock.string(from: ctx.date)
                // Gegen Einbrennen: Ziffern wandern jede Minute ein Stück
                let m = Calendar.current.component(.minute, from: ctx.date)
                let dx = CGFloat((m * 37) % 61 - 30), dy = CGFloat((m * 53) % 41 - 20)
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 14) {
                        Text(f)
                            .font(.system(size: 160, weight: .thin).monospacedDigit())
                            .minimumScaleFactor(0.4).lineLimit(1)
                            .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.12).opacity(0.55))
                        if let n = alarms.next {
                            Label(n.alarm.timeText, systemImage: "alarm.fill")
                                .font(.title3.weight(.medium))
                                .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.12).opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                    .offset(x: dx, y: dy)
                }
                .contentShape(Rectangle())
                .onTapGesture { night.end() }
            }
            .transition(.opacity)
            .accessibilityLabel("Nachtuhr. Zum Beenden tippen.")
        }
    }
}

extension DateFormatter {
    static let nightClock: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "H:mm"; return f
    }()
}
