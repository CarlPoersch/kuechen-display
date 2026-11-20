import UIKit

// ============================================================
// NightMode: Von 23:00 bis 06:00 wird das Display schwarz und so dunkel
// wie möglich. Die App (und der geführte Zugriff) läuft dabei weiter.
//
// Warum so und nicht "Bildschirm aus": iOS erlaubt Apps nicht, das Display
// abzuschalten oder das Gerät später selbst wieder aufzuwecken. Ginge das
// iPad in den Ruhezustand, käme es um 6 Uhr nicht von allein zurück.
// Helligkeit 0 + schwarzes Bild ist beim iPad mini praktisch "aus".
//
// Antippen in der Nacht: Hubert ist für 30 Sekunden normal zu sehen.
// ============================================================
final class NightMode: NSObject {
    static let startHour = 23   // ab 23:00 dunkel
    static let endHour = 6      // ab 06:00 wieder hell
    private static let peekSeconds: TimeInterval = 30

    private weak var host: UIView?
    private let overlay = UIView()
    private var timer: Timer?
    private var isNight = false
    private var peekUntil: Date?
    private let savedKey = "hubert.dayBrightness"

    init(host: UIView) {
        self.host = host
        super.init()
        overlay.backgroundColor = .black
        overlay.isHidden = true
        overlay.frame = host.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(peek)))
        host.addSubview(overlay)
        // Jede halbe Minute prüfen, ob gerade Nacht ist
        timer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(tick),
                                     userInfo: nil, repeats: true)
        tick()
    }

    private var screen: UIScreen? { host?.window?.windowScene?.screen ?? UIScreen.main }

    static func nightNow(_ date: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        return h >= startHour || h < endHour
    }

    @objc func tick() {
        let night = NightMode.nightNow()
        let peeking = (peekUntil ?? .distantPast) > Date()
        if night && !peeking { goDark() } else { goLight() }
    }

    /// Nach dem Zurückholen der App (z. B. aus dem Hintergrund) sofort neu prüfen
    func refresh() { tick() }

    @objc private func peek() {
        peekUntil = Date().addingTimeInterval(NightMode.peekSeconds)
        goLight()
        Timer.scheduledTimer(timeInterval: NightMode.peekSeconds + 0.5, target: self, selector: #selector(tick),
                             userInfo: nil, repeats: false)
    }

    private func goDark() {
        guard let host = host else { return }
        if !isNight, let s = screen, s.brightness > 0.05 {
            // Tageshelligkeit merken, damit sie morgens zurückkommt
            UserDefaults.standard.set(Double(s.brightness), forKey: savedKey)
        }
        isNight = true
        host.bringSubviewToFront(overlay)
        overlay.isHidden = false
        screen?.brightness = 0
    }

    private func goLight() {
        overlay.isHidden = true
        guard isNight else { return }
        isNight = false
        let saved = UserDefaults.standard.double(forKey: savedKey)
        screen?.brightness = CGFloat(saved > 0.05 ? saved : 0.7)
    }
}
