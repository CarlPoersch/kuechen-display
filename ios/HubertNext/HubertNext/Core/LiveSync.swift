import Foundation
import Combine

// ============================================================
// Live-Abgleich im Haushalt: laufende Timer, das Rezept, das gerade
// gekocht wird (inkl. Schritt), Einkaufsliste und Wochenplan.
//
// Wie: Supabase Realtime (WebSocket). Ändert ein Gerät etwas, meldet der
// Server es sofort allen anderen; die holen dann den aktuellen Stand.
// Zusätzlich: Abgleich beim Öffnen der App und alle 15 s – falls der
// WebSocket mal hängt, bleibt es trotzdem synchron.
// ============================================================

/// Kennung dieses Geräts (um eigene Änderungen zu erkennen)
enum Device {
    static let id: String = {
        if let s = UserDefaults.standard.string(forKey: "device.id") { return s }
        let s = UUID().uuidString.lowercased()
        UserDefaults.standard.set(s, forKey: "device.id")
        return s
    }()
}

/// Zeitstempel wie Postgres sie liefert (mit und ohne Sekundenbruchteile)
enum ISO {
    private static let frac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let plain = ISO8601DateFormatter()
    static func string(_ d: Date) -> String { frac.string(from: d) }
    static func date(_ s: String) -> Date? { frac.date(from: s) ?? plain.date(from: s) }
}

struct LiveTimerRow: Codable {
    let id: String
    let household_id: String
    let name: String
    let total_secs: Double
    let end_at: String
    let paused_left: Double?
    let source: String?
    let icon: String?
    let device: String?
    var done_at: String? = nil   // gesetzt = beendet (gestoppt oder „OK“ gedrückt)

    init(_ t: KitchenTimer, household: String) {
        id = t.id.uuidString.lowercased(); household_id = household; name = t.name; total_secs = t.total
        end_at = ISO.string(t.end); paused_left = t.pausedLeft; source = t.source; icon = t.icon; device = Device.id
    }

    enum CodingKeys: String, CodingKey { case id, household_id, name, total_secs, end_at, paused_left, source, icon, device, done_at }

    /// Beim Senden: paused_left immer mitschicken (auch leer – sonst bliebe „pausiert“ nach dem Fortsetzen
    /// auf dem Server stehen); done_at nie (Beenden geht nur über `finish`, damit nichts wiederaufersteht).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(household_id, forKey: .household_id); try c.encode(name, forKey: .name)
        try c.encode(total_secs, forKey: .total_secs); try c.encode(end_at, forKey: .end_at)
        try c.encode(paused_left, forKey: .paused_left)
        try c.encodeIfPresent(source, forKey: .source); try c.encodeIfPresent(icon, forKey: .icon); try c.encodeIfPresent(device, forKey: .device)
    }

    var timer: KitchenTimer? {
        guard let u = UUID(uuidString: id), let end = ISO.date(end_at) else { return nil }
        return KitchenTimer(id: u, name: name, total: total_secs, end: end, pausedLeft: paused_left, source: source, icon: icon)
    }
}

struct LiveCookingRow: Codable {
    let household_id: String
    let recipe_id: String
    let portions: Int
    let page: Int
    let device: String?
    var active: Bool? = true     // false = beendet (statt Löschen, siehe Migration 007)
}

final class LiveSync {
    static let shared = LiveSync()
    private var household: String?
    private var socket: URLSessionWebSocketTask?
    private var heartbeat: AnyCancellable?
    private var poll: AnyCancellable?
    private var ref = 0
    private var pulling = false
    private var pullAgain = false
    private var retry = 1.0
    private var sentToken: String?
    private let api = SupabaseClient.shared

    /// Starten bzw. auf einen anderen Haushalt umstellen
    func start(household h: String?) {
        guard let h = h else { stop(); return }
        if h != household || socket == nil {
            household = h
            TimerCenter.shared.household = h
            CookSession.shared.household = h
            connect()
        }
        Task { await pull() }
        poll = Timer.publish(every: 15, on: .main, in: .common).autoconnect().sink { _ in
            Task { @MainActor in await LiveSync.shared.pull() }
        }
    }

    /// App im Hintergrund: Verbindung schließen (iOS würde sie ohnehin kappen)
    func pause() {
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
        heartbeat = nil; poll = nil
    }

    func stop() {
        pause()
        household = nil
        TimerCenter.shared.household = nil
        CookSession.shared.household = nil
    }

    // MARK: Abgleich

    /// Aktuellen Stand holen und übernehmen
    func pull() async {
        guard let h = household else { return }
        if pulling { pullAgain = true; return }
        pulling = true
        defer { pulling = false }
        repeat {
            pullAgain = false
            do {
                async let t: [LiveTimerRow] = api.select("kitchen_timers", ["household_id": "eq." + h])
                async let c: [LiveCookingRow] = api.select("kitchen_cooking", ["household_id": "eq." + h])
                let (timers, cooking) = try await (t, c)
                TimerCenter.shared.apply(remote: timers)
                await CookSession.shared.apply(remote: cooking.first.flatMap { $0.active == false ? nil : $0 })
            } catch {
                print("Live-Abgleich:", error)
            }
        } while pullAgain
    }

    // MARK: Realtime (Phoenix-Protokoll von Supabase)

    private func connect() {
        socket?.cancel(with: .goingAway, reason: nil)
        var comps = URLComponents(url: Config.supabaseURL.appendingPathComponent("/realtime/v1/websocket"), resolvingAgainstBaseURL: false)!
        comps.scheme = "wss"
        comps.queryItems = [URLQueryItem(name: "apikey", value: Config.supabaseKey), URLQueryItem(name: "vsn", value: "1.0.0")]
        let ws = URLSession.shared.webSocketTask(with: comps.url!)
        socket = ws
        ws.resume()
        receive(ws)
        Task { await join() }
        heartbeat = Timer.publish(every: 25, on: .main, in: .common).autoconnect().sink { _ in
            Task { @MainActor in await LiveSync.shared.beat() }
        }
    }

    private func join() async {
        guard let h = household, let token = await api.currentToken() else { return }
        sentToken = token
        // Je Tabelle: Einfügen/Ändern nur für unseren Haushalt; Löschen ohne Filter,
        // weil Supabase Lösch-Ereignisse nicht filtern kann (dann wird eben kurz nachgesehen).
        let tables = ["kitchen_timers", "kitchen_cooking", "kitchen_items", "kitchen_plan"]
        var changes: [[String: Any]] = []
        for t in tables {
            changes.append(["event": "INSERT", "schema": "public", "table": t, "filter": "household_id=eq." + h])
            changes.append(["event": "UPDATE", "schema": "public", "table": t, "filter": "household_id=eq." + h])
            changes.append(["event": "DELETE", "schema": "public", "table": t])
        }
        send(["topic": "realtime:hubert-" + h, "event": "phx_join", "ref": next(), "join_ref": "1",
              "payload": ["config": ["broadcast": ["self": false], "presence": ["key": ""], "postgres_changes": changes],
                          "access_token": token]])
    }

    private func beat() async {
        guard socket != nil else { if household != nil { connect() }; return }
        send(["topic": "phoenix", "event": "heartbeat", "payload": [:], "ref": next()])
        // Anmeldung läuft nach 1 Std. ab → neuen Schlüssel nachreichen
        if let h = household, let token = await api.currentToken(), token != sentToken {
            sentToken = token
            send(["topic": "realtime:hubert-" + h, "event": "access_token", "payload": ["access_token": token], "ref": next()])
        }
    }

    private func next() -> String { ref += 1; return String(ref) }

    private func send(_ msg: [String: Any]) {
        guard let ws = socket, let d = try? JSONSerialization.data(withJSONObject: msg), let s = String(data: d, encoding: .utf8) else { return }
        ws.send(.string(s)) { @Sendable _ in }
    }

    private func receive(_ ws: URLSessionWebSocketTask) {
        ws.receive { @Sendable result in
            Task { @MainActor in LiveSync.shared.handle(result, from: ws) }
        }
    }

    private func handle(_ result: Result<URLSessionWebSocketTask.Message, Error>, from ws: URLSessionWebSocketTask) {
        guard ws === socket else { return }   // alte Verbindung
        switch result {
        case .failure:
            // Verbindung weg → nach kurzer Pause neu verbinden (1 s, 2 s, 4 s … max. 30 s)
            socket = nil; heartbeat = nil
            let wait = retry; retry = min(30, retry * 2)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                let l = LiveSync.shared
                if l.household != nil, l.socket == nil, l.poll != nil { l.connect() }
            }
        case .success(let msg):
            retry = 1
            if case .string(let s) = msg,
               let obj = (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any],
               let event = obj["event"] as? String {
                if event == "postgres_changes" { changed(obj) }
                if event == "phx_reply", let p = obj["payload"] as? [String: Any], p["status"] as? String == "ok" { Task { await pull() } }
            }
            receive(ws)
        }
    }

    /// Ein anderes Gerät hat etwas geändert
    private func changed(_ obj: [String: Any]) {
        let table = ((obj["payload"] as? [String: Any])?["data"] as? [String: Any])?["table"] as? String ?? ""
        switch table {
        case "kitchen_items", "kitchen_plan":
            Task { await KitchenStore.shared.sync(household: household, force: true) }
        default:
            Task { await pull() }
        }
    }
}
