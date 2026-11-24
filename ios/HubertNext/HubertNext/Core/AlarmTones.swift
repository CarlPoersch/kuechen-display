import Foundation
import UserNotifications

// ============================================================
// Wecktöne – alle selbst erzeugt (keine fremden Aufnahmen, keine Rechte-Fragen).
// Jeder Ton ist ein kurzes Muster, das in der App in Schleife läuft.
// Für Mitteilungen (Hubert zu) wird jedes Muster auf ~28 s verlängert und als
// WAV nach Library/Sounds geschrieben – dort sucht iOS eigene Mitteilungstöne.
// ============================================================

enum AlarmTone: String, CaseIterable, Identifiable {
    case standard, glocke, sanft, morgen, digital

    var id: String { rawValue }
    var label: String {
        switch self {
        case .standard: return "Klassisch"
        case .glocke: return "Glocke"
        case .sanft: return "Sanft"
        case .morgen: return "Morgen"
        case .digital: return "Digital"
        }
    }

    static func from(_ s: String) -> AlarmTone { AlarmTone(rawValue: s) ?? .standard }

    private static let rate = 44_100

    /// Ein Durchlauf des Musters als Abtastwerte (-1 … 1)
    private var pattern: [Double] {
        var out: [Double] = []
        let r = Double(Self.rate)
        func tone(_ secs: Double, _ freqs: [Double], decay: Double = 0, vol: Double = 0.6) {
            let n = Int(secs * r)
            for i in 0..<n {
                let t = Double(i) / r
                let edge = min(1, min(t, secs - t) / 0.01)                  // gegen Knackser
                let env = decay > 0 ? exp(-t * decay) : 1
                var v = 0.0
                for (k, f) in freqs.enumerated() { v += sin(2 * .pi * f * t) / Double(k + 1) }
                out.append(v / Double(freqs.count) * edge * env * vol)
            }
        }
        func pause(_ secs: Double) { out.append(contentsOf: repeatElement(0, count: Int(secs * r))) }

        switch self {
        case .standard:
            tone(0.16, [1046]); pause(0.08); tone(0.16, [1046]); pause(0.08); tone(0.16, [1318]); pause(0.7)
        case .glocke:
            tone(1.6, [660, 1320, 1980, 2640], decay: 2.2, vol: 0.9); pause(0.2)
        case .sanft:
            for f in [523.25, 659.25, 783.99] { tone(0.45, [f, f * 2], decay: 1.5, vol: 0.7) }
            pause(0.8)
        case .morgen:
            for f in [587.33, 739.99, 880, 1174.66, 880, 739.99] { tone(0.18, [f, f * 3], decay: 9, vol: 0.9); pause(0.04) }
            pause(0.5)
        case .digital:
            for _ in 0..<4 { tone(0.07, [2000]); pause(0.06) }
            pause(0.5)
        }
        return out
    }

    /// WAV (16 Bit, mono) – `repeatTo` > 0: Muster wiederholen bis zu dieser Länge (für Mitteilungen)
    func wav(repeatTo seconds: Double = 0) -> Data {
        var samples = pattern
        if seconds > 0, !samples.isEmpty {
            let target = Int(seconds * Double(Self.rate))
            let one = samples
            while samples.count + one.count <= target { samples += one }
        }
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        let dataLen = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + dataLen); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(Self.rate)); u32(UInt32(Self.rate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(dataLen)
        for s in samples {
            let v = Int16(max(-1, min(1, s)) * Double(Int16.max))
            u16(UInt16(bitPattern: v))
        }
        return d
    }

    // MARK: Mitteilungstöne

    var notificationFile: String { "hubert-\(rawValue)-v1.wav" }   // bei geänderten Tönen hochzählen

    var notificationSound: UNNotificationSound {
        Self.installed ? UNNotificationSound(named: UNNotificationSoundName(notificationFile)) : .default
    }

    private static var installed = false

    /// Einmal pro Start: alle Töne nach Library/Sounds schreiben (fehlen sie, gibt es den Standardton)
    static func installNotificationSounds() {
        guard !installed,
              let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let dir = lib.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var ok = true
        for t in allCases {
            let url = dir.appendingPathComponent(t.notificationFile)
            if FileManager.default.fileExists(atPath: url.path) { continue }
            do { try t.wav(repeatTo: 28).write(to: url) } catch { ok = false }
        }
        installed = ok
    }
}
