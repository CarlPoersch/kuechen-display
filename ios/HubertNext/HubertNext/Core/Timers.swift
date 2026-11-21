import SwiftUI
import Combine
import AudioToolbox
import UserNotifications

// ============================================================
// Timer: mehrere gleichzeitig, mit Namen ("Reis", "Schritt 3").
// Läuft ein Timer ab, klingelt Hubert und zeigt einen großen Hinweis –
// über allem, egal wo man gerade ist. Ist die App im Hintergrund,
// kommt eine Mitteilung.
// ============================================================

struct KitchenTimer: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var total: TimeInterval
    var end: Date
    var pausedLeft: TimeInterval?   // gesetzt = pausiert

    var left: TimeInterval { pausedLeft ?? max(0, end.timeIntervalSinceNow) }
    var progress: Double { total > 0 ? 1 - left / total : 1 }
}

final class TimerCenter: ObservableObject {
    static let shared = TimerCenter()
    @Published private(set) var timers: [KitchenTimer] = []
    @Published private(set) var ringing: [KitchenTimer] = []
    @Published private(set) var tick = Date()
    private var clock: AnyCancellable?
    private var lastBeep = Date.distantPast

    func start(_ name: String, minutes: Double) {
        let secs = max(5, minutes * 60)
        let t = KitchenTimer(name: name, total: secs, end: Date().addingTimeInterval(secs))
        timers.append(t)
        notify(t)
        run()
    }

    func cancel(_ t: KitchenTimer) {
        timers.removeAll { $0.id == t.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [t.id.uuidString])
    }

    func pause(_ t: KitchenTimer) {
        guard let i = timers.firstIndex(where: { $0.id == t.id }) else { return }
        if let left = timers[i].pausedLeft {
            timers[i].end = Date().addingTimeInterval(left); timers[i].pausedLeft = nil; notify(timers[i])
        } else {
            timers[i].pausedLeft = timers[i].left
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [t.id.uuidString])
        }
    }

    func add(_ t: KitchenTimer, minutes: Double) {
        guard let i = timers.firstIndex(where: { $0.id == t.id }) else { return }
        timers[i].end.addTimeInterval(minutes * 60); timers[i].total += minutes * 60
        notify(timers[i])
    }

    /// Klingeln beenden (optional: noch 1 Minute)
    func dismiss(_ t: KitchenTimer, snooze: Bool = false) {
        ringing.removeAll { $0.id == t.id }
        if snooze { start(t.name, minutes: 1) }
    }

    private func run() {
        guard clock == nil else { return }
        clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] now in
            Task { @MainActor in self?.step(now) }
        }
    }

    private func step(_ now: Date) {
        tick = now
        let done = timers.filter { $0.pausedLeft == nil && $0.end <= now }
        if !done.isEmpty {
            timers.removeAll { t in done.contains { $0.id == t.id } }
            ringing += done
        }
        // Klingeln alle 2 s, bis jemand "OK" drückt
        if !ringing.isEmpty, now.timeIntervalSince(lastBeep) >= 2 {
            lastBeep = now
            AudioServicesPlayAlertSound(1005)
        }
        if timers.isEmpty && ringing.isEmpty { clock?.cancel(); clock = nil }
    }

    /// Mitteilung, falls die App gerade nicht offen ist
    private func notify(_ t: KitchenTimer) {
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        c.removePendingNotificationRequests(withIdentifiers: [t.id.uuidString])
        let content = UNMutableNotificationContent()
        content.title = "⏰ " + t.name
        content.body = "Timer ist abgelaufen."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, t.end.timeIntervalSinceNow), repeats: false)
        c.add(UNNotificationRequest(identifier: t.id.uuidString, content: content, trigger: trigger))
    }

    static func format(_ secs: TimeInterval) -> String {
        let s = Int(secs.rounded(.up))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: Ansichten

/// Großer Hinweis, wenn ein Timer abgelaufen ist (liegt über der ganzen App)
struct TimerAlarmOverlay: View {
    @ObservedObject private var center = TimerCenter.shared

    var body: some View {
        if let t = center.ringing.first {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 18) {
                    Image(systemName: "bell.badge.fill").font(.system(size: 54)).foregroundColor(Theme.accent)
                        .symbolRenderingMode(.hierarchical)
                    Text(t.name).font(.system(size: 30, weight: .bold)).multilineTextAlignment(.center)
                    Text("Timer abgelaufen").font(.title3).foregroundColor(Theme.secondary)
                    HStack(spacing: 12) {
                        Button { center.dismiss(t, snooze: true) } label: {
                            Text("+1 Min.").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                        }
                        Button { center.dismiss(t) } label: {
                            Text("OK").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(28)
                .frame(maxWidth: 380)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.card))
                .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
                .padding(24)
            }
            .transition(.opacity)
        }
    }
}

/// Ein laufender Timer als Zeile (Ring, Name, Restzeit, Knöpfe)
struct TimerRow: View {
    let timer: KitchenTimer
    var compact = false
    @ObservedObject private var center = TimerCenter.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color(UIColor.tertiarySystemFill), lineWidth: 4)
                Circle().trim(from: 0, to: timer.progress).stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(timer.name).font(compact ? .subheadline : .headline).lineLimit(1)
                if timer.pausedLeft != nil { Text("Pausiert").font(.caption).foregroundColor(Theme.secondary) }
            }
            Spacer(minLength: 4)
            Text(TimerCenter.format(timer.left)).font((compact ? Font.headline : .title2).monospacedDigit().weight(.semibold))
                .foregroundColor(timer.left < 60 ? Theme.accent : .primary)
            if !compact {
                Button { center.add(timer, minutes: 1) } label: { Text("+1").font(.subheadline.weight(.semibold)).frame(width: 40, height: 34) }
                    .buttonStyle(.borderless)
                Button { center.pause(timer) } label: {
                    Image(systemName: timer.pausedLeft == nil ? "pause.fill" : "play.fill").frame(width: 34, height: 34)
                }
                .buttonStyle(.borderless)
                Button(role: .destructive) { center.cancel(timer) } label: { Image(systemName: "xmark").frame(width: 34, height: 34) }
                    .buttonStyle(.borderless)
            }
        }
        .id(center.tick)   // jede Sekunde neu zeichnen
    }
}

/// App "Timer": laufende Timer + schnell einen neuen starten
struct TimerToolView: View {
    @ObservedObject private var center = TimerCenter.shared
    @State private var name = ""
    @State private var minutes = 10

    private let presets: [Double] = [1, 3, 5, 8, 10, 12, 15, 20, 30, 45]

    var body: some View {
        List {
            if !center.timers.isEmpty {
                Section(header: Text("Läuft")) {
                    ForEach(center.timers) { TimerRow(timer: $0).padding(.vertical, 4) }
                }
            }
            Section(header: Text("Schnellstart")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 10) {
                    ForEach(presets, id: \.self) { m in
                        Button { center.start(name.isEmpty ? "\(Int(m)) Min." : name, minutes: m) } label: {
                            Text("\(Int(m))\nMin.").font(.headline).multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent.opacity(0.12)))
                                .foregroundColor(Theme.accent)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 6)
            }
            Section(header: Text("Eigener Timer")) {
                TextField("Name, z. B. Nudeln", text: $name)
                Stepper("\(minutes) Minuten", value: $minutes, in: 1...240)
                Button { center.start(name.isEmpty ? "Timer" : name, minutes: Double(minutes)); name = "" } label: {
                    Label("Starten", systemImage: "play.fill").font(.headline)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
