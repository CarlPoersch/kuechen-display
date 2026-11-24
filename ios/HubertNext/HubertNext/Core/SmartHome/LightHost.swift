import SwiftUI
import Combine

// ============================================================
// Lichtgerät: Welches Gerät schaltet Lampen für Wecker und Timer?
// Jedes Gerät mit offenem Hubert, das Lampen im WLAN erreicht, meldet sich alle 15 s
// (Tabelle light_hosts). Geschaltet wird nur vom gewählten Gerät – sonst würden
// mehrere Geräte gleichzeitig schalten (Flackern). Wahl: Wanddisplays zuerst,
// dann das Gerät, auf dem Hubert am längsten läuft.
// ============================================================

final class LightHost: ObservableObject {
    static let shared = LightHost()

    @Published private(set) var isHost = false
    @Published private(set) var hostName: String?
    @Published var isWall: Bool {
        didSet { UserDefaults.standard.set(isWall, forKey: "device.wall") }
    }

    private let started = Date()
    private var lastRefresh = Date.distantPast
    private let api = SupabaseClient.shared

    private struct Row: Codable {
        let household_id: String
        let device: String
        let name: String
        let wall: Bool
        let started_at: String
        let seen_at: String
    }

    init() {
        isWall = (UserDefaults.standard.object(forKey: "device.wall") as? Bool) ?? (UIDevice.current.userInterfaceIdiom == .pad)
    }

    /// Gibt es überhaupt Lampen? (sonst ist alles rund ums Licht ausgeblendet)
    static var hasLights: Bool { !SmartHomeStore.shared.lights.isEmpty }

    /// Alle 15 s (aus dem Live-Abgleich): melden, wer schalten kann, und das Lichtgerät bestimmen
    func beat(household h: String) async {
        let store = SmartHomeStore.shared
        guard !store.lights.isEmpty else {
            if isHost { isHost = false }
            hostName = nil
            return
        }
        // Zustände ab und zu auffrischen, auch wenn die Smart-Home-Karte nicht sichtbar ist
        if Date().timeIntervalSince(lastRefresh) > 60 {
            lastRefresh = Date()
            Task { await store.refresh(household: h) }   // nicht abwarten: die Suche im WLAN kann dauern
        }
        let active = UIApplication.shared.applicationState == .active
        let reaches = store.devices.contains { !$0.ip.isEmpty && !store.unreachable.contains($0.id) }
        let me = Device.id
        if active && reaches {
            let row = Row(household_id: h, device: me, name: AppStore.deviceName + (isWall ? " (Wanddisplay)" : ""),
                          wall: isWall, started_at: ISO.string(started), seen_at: ISO.string(Date()))
            try? await api.upsert("light_hosts", [row])
        } else {
            try? await api.delete("light_hosts", ["household_id": "eq." + h, "device": "eq." + me])
        }
        guard let rows: [Row] = try? await api.select("light_hosts", ["household_id": "eq." + h]) else { return }
        let now = Date()
        let alive = rows.filter { (ISO.date($0.seen_at).map { now.timeIntervalSince($0) < 60 }) ?? false }
        let host = alive.sorted { a, b in
            if a.wall != b.wall { return a.wall }
            let sa = ISO.date(a.started_at) ?? now, sb = ISO.date(b.started_at) ?? now
            return sa != sb ? sa < sb : a.device < b.device
        }.first
        isHost = host?.device == me
        hostName = host?.name
    }
}

/// Lampen auswählen (für Wecker und Timer). Zeigt alle Lampen aus dem Smart-Home-Bucket.
struct LampPicker: View {
    @Binding var selection: [String]
    @ObservedObject private var store = SmartHomeStore.shared

    var body: some View {
        List {
            Section {
                ForEach(store.lights) { l in
                    Button {
                        if selection.contains(l.id) { selection.removeAll { $0 == l.id } } else { selection.append(l.id) }
                    } label: {
                        HStack {
                            Image(systemName: "lightbulb.fill").foregroundColor(.yellow).frame(width: 28)
                            Text(l.name).foregroundColor(.primary)
                            Spacer()
                            if selection.contains(l.id) {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundColor(Theme.accent)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                HStack {
                    Button("Alle") { selection = store.lights.map(\.id) }
                    Text("·")
                    Button("Keine") { selection = [] }
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Lampen")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Kurztext für die Zeile davor: „Alle“, „Stehlampe“, „2 Lampen“
    static func summary(_ ids: [String]) -> String {
        let lights = SmartHomeStore.shared.lights
        let chosen = lights.filter { ids.contains($0.id) }
        if chosen.isEmpty { return "Keine" }
        if chosen.count == lights.count && lights.count > 1 { return "Alle" }
        return chosen.count == 1 ? chosen[0].name : "\(chosen.count) Lampen"
    }
}

/// Hinweis, welches Gerät gerade das Licht schaltet
struct LightHostNote: View {
    @ObservedObject private var host = LightHost.shared

    var body: some View {
        if let n = host.hostName {
            Text("Das Licht schaltet gerade: \(n)\(host.isHost ? " – dieses Gerät" : "").")
        } else {
            Text("Gerade schaltet kein Gerät das Licht. Hubert muss zu Hause auf einem Gerät offen sein, am besten auf dem Wand-iPad.")
                .foregroundColor(.orange)
        }
    }
}
