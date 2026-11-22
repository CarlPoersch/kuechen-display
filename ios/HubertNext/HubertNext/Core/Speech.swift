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
        Task { @MainActor in
            // Erlaubnisse abfragen. Die Rückrufe kommen auf Hintergrund-Threads an → nur über
            // @Sendable-Rückrufe mit Continuation, sonst beendet iOS die App (Absturz beim Antippen).
            let speech = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                SFSpeechRecognizer.requestAuthorization { @Sendable s in c.resume(returning: s) }
            }
            guard speech == .authorized else { problem = "Spracherkennung ist nicht erlaubt (Einstellungen → Hubert)."; return }
            let mic = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { @Sendable ok in c.resume(returning: ok) }
            }
            guard mic else { problem = "Mikrofon ist nicht erlaubt (Einstellungen → Hubert)."; return }
            begin()
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

            // Schwacher Verweis in einer festen Box: Die Rückrufe laufen auf anderen Threads; eine
            // „weak var self“ dort wäre eine veränderliche Variable (Swift-6-Fehler), die Box ist eine Konstante.
            let me = WeakRef(self)
            task = recognizer.recognitionTask(with: req) { @Sendable result, error in
                if let r = result {
                    let words = r.bestTranscription.formattedString.lowercased().split(separator: " ").map(String.init)
                    Task { @MainActor in me.value?.handle(words) }
                }
                if error != nil || result?.isFinal == true {
                    Task { @MainActor in if me.value?.listening == true { me.value?.begin() } }   // weiter zuhören
                }
            }
            listening = true; problem = nil
            // Apple begrenzt eine Erkennung auf etwa 1 Minute → regelmäßig neu starten
            restartTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: false) { @Sendable _ in
                Task { @MainActor in if me.value?.listening == true { me.value?.begin() } }
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

/// Schwacher Verweis als Konstante – darf in Rückrufe auf anderen Threads mitgenommen werden
final class WeakRef<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
