import Foundation
import Combine
import Speech
import AVFoundation

// ============================================================
// Sprachsteuerung im Kochmodus: Hubert hört auf
//   "weiter" / "nächster"  → nächster Schritt
//   "zurück"               → vorheriger Schritt
//   "Timer" / "starte"     → Timer des Schritts starten
//   "Zutaten"              → Zutatenliste
// Warum so wenige Wörter: Kurze, eindeutige Befehle werden auch mit
// Dunstabzug und Brutzeln im Hintergrund zuverlässig erkannt.
// Die Erkennung läuft, wenn das Gerät es kann, ohne Internet.
// ============================================================

enum CookCommand { case next, back, timer, ingredients }

final class SpeechControl: ObservableObject {
    @Published private(set) var listening = false
    @Published private(set) var heard = ""          // zuletzt erkanntes Wort (zur Rückmeldung)
    @Published var problem: String?

    var onCommand: ((CookCommand) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var used = 0              // wie viele Wörter des aktuellen Texts schon ausgewertet sind
    private var restartTimer: Timer?

    func toggle() { listening ? stop() : start() }

    func start() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.problem = "Spracherkennung ist nicht erlaubt (Einstellungen → Hubert)."; return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    DispatchQueue.main.async {
                        if ok { self.begin() } else { self.problem = "Mikrofon ist nicht erlaubt (Einstellungen → Hubert)." }
                    }
                }
            }
        }
    }

    func stop() {
        restartTimer?.invalidate(); restartTimer = nil
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        listening = false
    }

    private func begin() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            problem = "Spracherkennung gerade nicht verfügbar."; return
        }
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            req.contextualStrings = ["weiter", "zurück", "Timer", "Zutaten", "nächster"]
            request = req; used = 0

            let input = engine.inputNode
            // @Sendable: läuft auf dem Audio-Thread, nicht auf dem Hauptthread
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { @Sendable buffer, _ in
                req.append(buffer)
            }
            engine.prepare()
            try engine.start()

            task = recognizer.recognitionTask(with: req) { @Sendable [weak self] result, error in
                guard let self = self else { return }
                if let r = result {
                    let words = r.bestTranscription.formattedString.lowercased().split(separator: " ").map(String.init)
                    DispatchQueue.main.async { self.handle(words) }
                }
                if error != nil || result?.isFinal == true {
                    DispatchQueue.main.async { if self.listening { self.begin() } }   // weiter zuhören
                }
            }
            listening = true; problem = nil
            // Apple begrenzt eine Erkennung auf etwa 1 Minute → regelmäßig neu starten
            restartTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { if self?.listening == true { self?.begin() } }
            }
        } catch {
            problem = "Mikrofon konnte nicht starten."
            stop()
        }
    }

    /// Nur neue Wörter auswerten (Teilergebnisse wiederholen den bisherigen Text)
    private func handle(_ words: [String]) {
        guard words.count > used else { return }
        let fresh = words[used...]
        used = words.count
        for w in fresh {
            let cmd: CookCommand?
            switch w.trimmingCharacters(in: .punctuationCharacters) {
            case "weiter", "nächster", "nächste", "next": cmd = .next
            case "zurück", "vorher", "zurueck": cmd = .back
            case "timer", "starte", "start", "stoppuhr": cmd = .timer
            case "zutaten", "zutat": cmd = .ingredients
            default: cmd = nil
            }
            if let c = cmd { heard = w; onCommand?(c) }
        }
    }
}
