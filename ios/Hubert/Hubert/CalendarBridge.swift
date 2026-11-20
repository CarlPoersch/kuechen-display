import EventKit
import UIKit
import WebKit

// ============================================================
// CalendarBridge: liest die Termine aus der Kalender-App des Geräts
// und reicht sie an die Web-App weiter (window.HubertNative.setCalendar).
//
// Warum über das Gerät statt über die Cloud: Alle Kalender, die auf dem
// iPad/iPhone eingerichtet sind, sind automatisch dabei, und die Termine
// verlassen das Gerät nie.
// ============================================================
final class CalendarBridge {
    private let store = EKEventStore()
    private weak var webView: WKWebView?
    private var granted = false
    private var timer: Timer?

    init(webView: WKWebView) {
        self.webView = webView
        // Ändert sich etwas im Kalender (neuer Termin, Sync), sofort neu senden
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed), name: .EKEventStoreChanged, object: store)
        // Zusätzlich alle 10 Minuten, damit "Heute"/"Morgen" nach Mitternacht stimmt
        timer = Timer.scheduledTimer(timeInterval: 600, target: self, selector: #selector(changed),
                                     userInfo: nil, repeats: true)
    }

    // nonisolated: Die Meldung kann aus einem Hintergrund-Thread kommen,
    // gearbeitet wird danach auf dem Haupt-Thread.
    @objc nonisolated private func changed() {
        Task { @MainActor in self.push() }
    }

    /// Beim ersten Mal fragt iOS um Erlaubnis. Danach kommt die Antwort sofort.
    func requestAndPush() {
        // @Sendable: iOS ruft das aus einem Hintergrund-Thread auf
        let done: @Sendable (Bool, Error?) -> Void = { [weak self] ok, _ in
            guard let me = self else { return }
            Task { @MainActor in
                me.granted = ok
                me.push()
            }
        }
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents(completion: done)
        } else {
            store.requestAccess(to: .event, completion: done)
        }
    }

    /// Termine von heute 0 Uhr bis in 8 Tagen an die Web-App schicken
    func push() {
        guard let webView = webView else { return }
        guard granted else {
            webView.evaluateJavaScript("window.HubertNative && HubertNative.setCalendar(null, 'denied')")
            return
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 8, to: start) ?? start
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let iso = ISO8601DateFormatter()

        let list: [[String: Any]] = store.events(matching: pred)
            .sorted { $0.startDate < $1.startDate }
            .prefix(60)
            .map { e in
                var d: [String: Any] = [
                    "t": e.title ?? "Termin",
                    "s": iso.string(from: e.startDate),
                    "e": iso.string(from: e.endDate),
                    "a": e.isAllDay,
                    "k": e.calendar?.title ?? "",
                    "f": hex(e.calendar?.cgColor),
                ]
                if let loc = e.location, !loc.isEmpty { d["o"] = loc }
                return d
            }

        guard let data = try? JSONSerialization.data(withJSONObject: list),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.HubertNative && HubertNative.setCalendar(\(json), 'ok')")
    }

    private func hex(_ c: CGColor?) -> String {
        guard let c = c else { return "#8a7d72" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(cgColor: c).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
