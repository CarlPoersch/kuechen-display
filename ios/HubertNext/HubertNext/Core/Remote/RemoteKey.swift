import Foundation

// ============================================================
// Tasten der Fernbedienung – einmal für alle Geräte, je Geräteart übersetzt.
// Philips: Tastennamen der JointSPACE-Schnittstelle ("CursorUp" …)
// Android TV: KeyEvent-Codes von Android (KEYCODE_DPAD_UP = 19 …)
// ============================================================

enum RemoteKey: String, CaseIterable {
    case power, up, down, left, right, ok, back, home
    case volumeUp, volumeDown, mute
    case playPause, channelUp, channelDown, source, menu, info

    /// Philips JointSPACE (input/key)
    var philips: String? {
        switch self {
        case .power: return "Standby"
        case .up: return "CursorUp"
        case .down: return "CursorDown"
        case .left: return "CursorLeft"
        case .right: return "CursorRight"
        case .ok: return "Confirm"
        case .back: return "Back"
        case .home: return "Home"
        case .volumeUp: return "VolumeUp"
        case .volumeDown: return "VolumeDown"
        case .mute: return "Mute"
        case .playPause: return "PlayPause"
        case .channelUp: return "ChannelStepUp"
        case .channelDown: return "ChannelStepDown"
        case .source: return "Source"
        case .menu: return "Options"
        case .info: return "Info"
        }
    }

    /// Android KeyEvent-Code
    var android: Int? {
        switch self {
        case .power: return 26
        case .up: return 19
        case .down: return 20
        case .left: return 21
        case .right: return 22
        case .ok: return 23
        case .back: return 4
        case .home: return 3
        case .volumeUp: return 24
        case .volumeDown: return 25
        case .mute: return 164
        case .playPause: return 85
        case .channelUp: return 166
        case .channelDown: return 167
        case .source: return nil
        case .menu: return 82
        case .info: return 165
        }
    }

    /// Wiederholen beim langen Drücken
    var repeats: Bool { [.up, .down, .left, .right, .volumeUp, .volumeDown].contains(self) }

    var label: String {
        switch self {
        case .power: return "Ein/Aus"
        case .up: return "Hoch"
        case .down: return "Runter"
        case .left: return "Links"
        case .right: return "Rechts"
        case .ok: return "OK"
        case .back: return "Zurück"
        case .home: return "Home"
        case .volumeUp: return "Lauter"
        case .volumeDown: return "Leiser"
        case .mute: return "Ton aus"
        case .playPause: return "Wiedergabe/Pause"
        case .channelUp: return "Programm hoch"
        case .channelDown: return "Programm runter"
        case .source: return "Quelle"
        case .menu: return "Menü"
        case .info: return "Info"
        }
    }
}
