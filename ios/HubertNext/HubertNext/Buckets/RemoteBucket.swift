import SwiftUI
import Combine

// ============================================================
// Fernbedienung: Philips-Fernseher (JointSPACE) und Android TV /
// Google TV wie den Xiaomi Mi TV Stick (Android TV Remote v2).
// Nur im selben WLAN. Design: docs/specs/2026-11-23-fernbedienung-design.md
// Einstellungen: devices = [{ id, name, kind: philips|androidtv, host, philips: { api, secure } }]
// ============================================================

enum RemoteBucket {
    static let kind = BucketKind(
        id: "fernbedienung", name: "Fernbedienung", symbol: "tv.and.mediabox", tint: .gray, art: .glance,
        interests: ["technik", "haushalt"], blurb: "Fernseher und TV-Stick im WLAN steuern – Philips und Android TV.",
        sizes: [.s, .m], defaultSize: .s,
        glance: { inst, _ in AnyView(RemoteGlance(bucketId: inst.id, config: inst.config)) },
        detail: { inst in AnyView(RemoteApp(bucketId: inst.id)) },
        settings: { binding in AnyView(RemoteSettings(config: binding)) }
    )
}

// MARK: Haptik

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

// MARK: Karte auf der Startseite

struct RemoteGlance: View {
    let bucketId: String
    let config: [String: JSON]
    @ObservedObject private var remote = RemoteController.shared
    @AppStorage("remote.selected") private var selected = ""

    var body: some View {
        let devices = RemoteDevice.list(config)
        if let d = devices.first(where: { $0.id == selected }) ?? devices.first {
            VStack(alignment: .leading, spacing: 10) {
                Label(d.name, systemImage: d.symbol).font(.headline).lineLimit(1)
                HStack(spacing: 10) {
                    glanceButton("power", .power, d, tint: true)
                    glanceButton("speaker.minus.fill", .volumeDown, d)
                    glanceButton("speaker.plus.fill", .volumeUp, d)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Noch kein Gerät").font(.headline)
                Text("Fernseher oder TV-Stick in den Einstellungen hinzufügen.").font(.subheadline).foregroundColor(Theme.secondary)
            }
        }
    }

    private func glanceButton(_ symbol: String, _ key: RemoteKey, _ d: RemoteDevice, tint: Bool = false) -> some View {
        Button {
            Haptic.tap()
            if remote.device?.id != d.id { remote.onVariant = nil; remote.open(d) }
            remote.press(key)
        } label: {
            Image(systemName: symbol).font(.title3.weight(.semibold))
                .foregroundColor(tint ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint ? Theme.accent : Color(UIColor.tertiarySystemFill)))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(key.label)
    }
}

// MARK: Fernbedienung (App)

struct RemoteApp: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @ObservedObject private var remote = RemoteController.shared
    @AppStorage("remote.selected") private var selected = ""
    @State private var pairing: RemoteDevice?
    @State private var adding = false
    @State private var typing = false

    private var devices: [RemoteDevice] { RemoteDevice.list(store.buckets.first { $0.id == bucketId }?.config ?? [:]) }
    private var current: RemoteDevice? { devices.first { $0.id == selected } ?? devices.first }

    var body: some View {
        Group {
            if let d = current {
                ScrollView {
                    VStack(spacing: 22) {
                        if devices.count > 1 { picker }
                        statusLine(d)
                        RemotePad(device: d, onText: { typing = true })
                    }
                    .frame(maxWidth: 440)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .background(Theme.background.ignoresSafeArea())
                .onAppear { connect(d) }
                .onChange(of: d.id) { _ in connect(d) }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "tv.and.mediabox").font(.system(size: 54)).foregroundColor(Theme.secondary)
                    Text("Noch kein Gerät").font(.title3.weight(.semibold))
                    Text("Fernseher und TV-Stick müssen im selben WLAN sein wie dieses Gerät.")
                        .font(.subheadline).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
                    Button { adding = true } label: {
                        Text("Gerät hinzufügen").font(.headline).foregroundColor(.white)
                            .padding(.horizontal, 22).frame(minHeight: 48)
                            .background(Capsule().fill(Theme.accent))
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.ignoresSafeArea())
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Gerät hinzufügen")
            }
        }
        .sheet(isPresented: $adding) {
            RemoteAddSheet { d in
                store.updateConfig(bucketId) { c in var l = RemoteDevice.list(c); l.append(d); RemoteDevice.store(l, in: &c) }
                selected = d.id
            }
        }
        .sheet(item: $pairing) { d in RemotePairSheet(device: d) }
        .sheet(isPresented: $typing) { RemoteTextSheet() }
        .onDisappear { remote.close() }
    }

    private func connect(_ d: RemoteDevice) {
        remote.onVariant = { [bucketId, store] dev in
            store.updateConfig(bucketId) { c in
                var l = RemoteDevice.list(c)
                if let i = l.firstIndex(where: { $0.id == dev.id }) { l[i] = dev }
                RemoteDevice.store(l, in: &c)
            }
        }
        remote.open(d)
    }

    private var picker: some View {
        Picker("Gerät", selection: Binding(get: { current?.id ?? "" }, set: { selected = $0 })) {
            ForEach(devices) { Text($0.name).tag($0.id) }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder private func statusLine(_ d: RemoteDevice) -> some View {
        switch remote.phase {
        case .connecting:
            HStack(spacing: 8) { ProgressView(); Text("Verbinde mit \(d.name) …").foregroundColor(Theme.secondary) }
                .font(.subheadline)
        case .needsPairing:
            notice("Einmal koppeln, dann geht es los.", button: "Koppeln") { pairing = d }
        case .failed(let msg):
            notice(msg, button: "Erneut versuchen") { remote.retry() }
        case .ready, .idle:
            HStack(spacing: 6) {
                Circle().fill(remote.phase == .ready ? Color.green : Theme.secondary).frame(width: 8, height: 8)
                Text(d.name + (remote.volume.map { " · Lautstärke \($0.muted ? "stumm" : "\($0.level)")" } ?? ""))
                    .font(.subheadline).foregroundColor(Theme.secondary)
            }
        }
    }

    private func notice(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.subheadline)
            HStack {
                Button(button, action: action).font(.subheadline.weight(.semibold))
                Spacer()
                if remote.phase != .needsPairing, let d = current {
                    Button("Neu koppeln") { RemoteController.forget(d); pairing = d }.font(.subheadline)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }
}

// MARK: Tastenfeld

struct RemotePad: View {
    let device: RemoteDevice
    let onText: () -> Void
    @ObservedObject private var remote = RemoteController.shared

    var body: some View {
        VStack(spacing: 26) {
            HStack {
                RemoteButton(key: .power, symbol: "power", style: .accent)
                Spacer()
                if device.kind == .philips {
                    RemoteButton(key: .source, symbol: "rectangle.on.rectangle", style: .plain)
                } else {
                    Button { Haptic.tap(); onText() } label: { RemoteButtonLabel(symbol: "keyboard", style: .plain) }
                        .buttonStyle(.plain).accessibilityLabel("Text eingeben")
                }
            }
            DPad()
            HStack {
                RemoteButton(key: .back, symbol: "arrow.uturn.backward", style: .plain)
                Spacer()
                RemoteButton(key: .home, symbol: "house.fill", style: .plain)
                Spacer()
                RemoteButton(key: .playPause, symbol: "playpause.fill", style: .plain)
            }
            HStack(alignment: .top) {
                Rocker(up: .volumeUp, down: .volumeDown, upSymbol: "plus", downSymbol: "minus", title: "Lautstärke")
                Spacer()
                RemoteButton(key: .mute, symbol: "speaker.slash.fill", style: .plain)
                Spacer()
                if device.kind == .philips {
                    Rocker(up: .channelUp, down: .channelDown, upSymbol: "chevron.up", downSymbol: "chevron.down", title: "Programm")
                } else {
                    RemoteButton(key: .menu, symbol: "line.3.horizontal", style: .plain)
                }
            }
        }
    }
}

enum RemoteButtonStyle { case plain, accent }

struct RemoteButtonLabel: View {
    let symbol: String
    let style: RemoteButtonStyle
    var size: CGFloat = 64
    var body: some View {
        Image(systemName: symbol).font(.system(size: size * 0.34, weight: .semibold))
            .foregroundColor(style == .accent ? .white : .primary)
            .frame(width: size, height: size)
            .background(Circle().fill(style == .accent ? Theme.accent : Theme.card))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

/// Taste mit Haptik; Pfeile und Lautstärke wiederholen sich beim Gedrückthalten
struct RemoteButton: View {
    let key: RemoteKey
    let symbol: String
    let style: RemoteButtonStyle
    var size: CGFloat = 64
    var body: some View {
        RepeatPress(key: key) { pressed in
            RemoteButtonLabel(symbol: symbol, style: style, size: size).opacity(pressed ? 0.6 : 1)
        }
        .accessibilityLabel(key.label)
    }
}

/// Tippen = senden; gedrückt halten = nach 0,4 s alle 0,15 s wiederholen (nur bei key.repeats).
/// Als Button gebaut, damit Scrollen über die Tasten keine Tasten auslöst.
struct RepeatPress<Content: View>: View {
    let key: RemoteKey
    @ViewBuilder let content: (Bool) -> Content
    @State private var repeated = false
    @State private var timer: Timer?

    var body: some View {
        Button {
            if !repeated { fire() }
            repeated = false
        } label: { EmptyView() }
        .buttonStyle(PressReporter(content: content) { pressed in changed(pressed) })
        .accessibilityLabel(key.label)
    }

    private func changed(_ pressed: Bool) {
        timer?.invalidate(); timer = nil
        guard pressed, key.repeats else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
            DispatchQueue.main.async {
                repeated = true
                fire()
                timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
                    DispatchQueue.main.async { fire() }
                }
            }
        }
    }

    private func fire() { Haptic.tap(); RemoteController.shared.press(key) }
}

/// Zeigt den gedrückten Zustand und meldet Drücken/Loslassen
struct PressReporter<C: View>: ButtonStyle {
    let content: (Bool) -> C
    let onPress: (Bool) -> Void
    func makeBody(configuration: Configuration) -> some View {
        content(configuration.isPressed)
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { onPress($0) }
    }
}

/// Rundes Steuerkreuz mit OK in der Mitte
struct DPad: View {
    var body: some View {
        let size: CGFloat = 250
        ZStack {
            Circle().fill(Theme.card).shadow(color: .black.opacity(0.06), radius: 10, y: 3)
            VStack {
                arrow(.up, "chevron.up"); Spacer(); arrow(.down, "chevron.down")
            }
            .padding(.vertical, 10)
            HStack {
                arrow(.left, "chevron.left"); Spacer(); arrow(.right, "chevron.right")
            }
            .padding(.horizontal, 10)
            RepeatPress(key: .ok) { pressed in
                Text("OK").font(.title3.weight(.bold)).foregroundColor(.white)
                    .frame(width: 92, height: 92)
                    .background(Circle().fill(Theme.accent))
                    .opacity(pressed ? 0.7 : 1)
            }
            .accessibilityLabel("OK")
        }
        .frame(width: size, height: size)
    }

    private func arrow(_ key: RemoteKey, _ symbol: String) -> some View {
        RepeatPress(key: key) { pressed in
            Image(systemName: symbol).font(.system(size: 26, weight: .semibold)).foregroundColor(.primary)
                .frame(width: 64, height: 64)
                .opacity(pressed ? 0.4 : 1)
        }
        .accessibilityLabel(key.label)
    }
}

/// Wippe (Lautstärke, Programm): oben +, unten −
struct Rocker: View {
    let up: RemoteKey
    let down: RemoteKey
    let upSymbol: String
    let downSymbol: String
    let title: String
    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 0) {
                RepeatPress(key: up) { p in
                    Image(systemName: upSymbol).font(.system(size: 20, weight: .bold)).frame(width: 64, height: 60).opacity(p ? 0.4 : 1)
                }
                .accessibilityLabel(up.label)
                Divider().frame(width: 34)
                RepeatPress(key: down) { p in
                    Image(systemName: downSymbol).font(.system(size: 20, weight: .bold)).frame(width: 64, height: 60).opacity(p ? 0.4 : 1)
                }
                .accessibilityLabel(down.label)
            }
            .foregroundColor(.primary)
            .background(Capsule().fill(Theme.card))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            Text(title).font(.caption).foregroundColor(Theme.secondary)
        }
    }
}

// MARK: Text an den Fernseher

struct RemoteTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focus: Bool

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Suchbegriff, Passwort …", text: $text)
                        .focused($focus).submitLabel(.send).disableAutocorrection(true)
                        .onSubmit(send)
                } footer: {
                    Text("Erst auf dem Fernseher ein Eingabefeld öffnen (z. B. die Suche), dann hier tippen.")
                }
            }
            .navigationTitle("Text eingeben").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Senden", action: send).disabled(text.isEmpty) }
            }
            .onAppear { focus = true }
        }
        .navigationViewStyle(.stack)
    }

    private func send() {
        guard !text.isEmpty else { return }
        RemoteController.shared.send(text: text)
        Haptic.tap()
        text = ""
    }
}

// MARK: Gerät hinzufügen

struct RemoteAddSheet: View {
    let onAdd: (RemoteDevice) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var finder = RemoteFinder()
    @State private var kind: RemoteDevice.Kind = .philips
    @State private var name = ""
    @State private var host = ""

    private var valid: Bool { !host.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Art", selection: $kind) {
                        Text("Philips-Fernseher").tag(RemoteDevice.Kind.philips)
                        Text("Android TV / Mi Stick").tag(RemoteDevice.Kind.androidtv)
                    }
                    .pickerStyle(.segmented)
                }
                if kind == .androidtv {
                    Section {
                        if finder.found.isEmpty {
                            HStack(spacing: 10) {
                                if finder.searching { ProgressView() }
                                Text(finder.searching ? "Suche im WLAN …" : "Nichts gefunden – IP-Adresse unten eingeben.")
                                    .foregroundColor(Theme.secondary)
                            }
                        }
                        ForEach(finder.found) { f in
                            Button {
                                name = f.name; host = f.host
                            } label: {
                                HStack {
                                    Label(f.name, systemImage: "tv.and.mediabox").foregroundColor(.primary)
                                    Spacer()
                                    if host == f.host { Image(systemName: "checkmark").foregroundColor(Theme.accent) }
                                }
                            }
                        }
                    } header: { Text("Gefunden") }
                }
                Section {
                    TextField("Name, z. B. Wohnzimmer", text: $name)
                    TextField("IP-Adresse, z. B. 192.168.178.40", text: $host)
                        .keyboardType(.numbersAndPunctuation).disableAutocorrection(true).textInputAutocapitalization(.never)
                } footer: {
                    Text(kind == .philips
                         ? "Die IP-Adresse steht am Fernseher unter Einstellungen → Netzwerk → Netzwerkeinstellungen anzeigen (je nach Modell etwas anders)."
                         : "Mi TV Stick: Einstellungen → Netzwerk & Internet → WLAN-Name → IP-Adresse.")
                }
            }
            .navigationTitle("Gerät hinzufügen").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let h = host.trimmingCharacters(in: .whitespaces)
                        let n = name.trimmingCharacters(in: .whitespaces)
                        onAdd(RemoteDevice(name: n.isEmpty ? (kind == .philips ? "Fernseher" : "TV-Stick") : n, kind: kind, host: h))
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
            .onAppear { finder.start() }
            .onDisappear { finder.stop() }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Koppeln

struct RemotePairSheet: View {
    let device: RemoteDevice
    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.start
    @State private var code = ""
    @State private var error: String?
    @State private var atv: ATVPairing?
    @State private var philips: PhilipsTV?

    enum Step { case start, waiting, code, checking, done }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    switch step {
                    case .start:
                        Text(device.kind == .philips
                             ? "Hubert fragt beim Fernseher an. Danach erscheint dort eine PIN."
                             : "Hubert fragt beim \(device.name) an. Danach erscheint auf dem Fernseher ein Code mit 6 Zeichen.")
                        Button("Kopplung starten") { start() }.font(.headline)
                    case .waiting:
                        HStack(spacing: 10) { ProgressView(); Text("Warte auf das Gerät …") }
                    case .code, .checking:
                        Text(device.kind == .philips ? "PIN vom Fernseher eingeben:" : "Code vom Fernseher eingeben (Ziffern und A–F):")
                        TextField(device.kind == .philips ? "PIN" : "z. B. 3F9A1C", text: $code)
                            .font(.title2.monospaced()).disableAutocorrection(true)
                            .textInputAutocapitalization(.characters)
                            .keyboardType(device.kind == .philips ? .numberPad : .asciiCapable)
                        Button { finish() } label: {
                            HStack { if step == .checking { ProgressView() }; Text("Koppeln").font(.headline) }
                        }
                        .disabled(code.count < 4 || step == .checking)
                    case .done:
                        Label("Gekoppelt", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                    }
                } footer: {
                    if let e = error { Text(e).foregroundColor(.red) }
                }
            }
            .navigationTitle(device.name + " koppeln").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(step == .done ? "Fertig" : "Abbrechen") { atv?.cancel(); dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }

    private func start() {
        error = nil; step = .waiting
        Task {
            do {
                switch device.kind {
                case .philips:
                    var variant = device.philips
                    if variant == nil { variant = await PhilipsTV.detect(host: device.host) }
                    guard let v = variant else { throw RemoteError.timeout }
                    guard v.secure else {      // ältere Modelle brauchen keine Kopplung
                        RemoteController.shared.paired(device)
                        step = .done; return
                    }
                    let tv = PhilipsTV(host: device.host, variant: v, credentials: nil)
                    try await tv.startPairing()
                    philips = tv
                case .androidtv:
                    let p = ATVPairing()
                    atv = p
                    try await p.start(host: device.host)
                }
                step = .code
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Kopplung nicht möglich."
                step = .start
            }
        }
    }

    private func finish() {
        error = nil; step = .checking
        let c = code.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                switch device.kind {
                case .philips:
                    guard let tv = philips else { throw RemoteError.message("Bitte neu starten.") }
                    let creds = try await tv.finishPairing(pin: c)
                    RemoteController.shared.paired(device, philips: creds)
                case .androidtv:
                    guard let p = atv else { throw RemoteError.message("Bitte neu starten.") }
                    try await p.finish(code: c)
                    RemoteController.shared.paired(device)
                }
                Haptic.tap()
                step = .done
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Kopplung fehlgeschlagen."
                step = .code
            }
        }
    }
}

// MARK: Einstellungen

struct RemoteSettings: View {
    @Binding var config: [String: JSON]
    @State private var adding = false

    var body: some View {
        let list = RemoteDevice.list(config)
        ForEach(list) { d in
            VStack(alignment: .leading, spacing: 2) {
                Label(d.name, systemImage: d.symbol)
                Text(d.kindLabel + " · " + d.host).font(.caption).foregroundColor(Theme.secondary)
            }
            .swipeActions {
                Button(role: .destructive) {
                    RemoteController.forget(d)
                    RemoteDevice.store(list.filter { $0.id != d.id }, in: &config)
                } label: { Label("Entfernen", systemImage: "trash") }
                Button { RemoteController.forget(d) } label: { Label("Kopplung vergessen", systemImage: "link") }
            }
        }
        Button { adding = true } label: { Label("Gerät hinzufügen", systemImage: "plus.circle.fill") }
            .sheet(isPresented: $adding) {
                RemoteAddSheet { d in var l = RemoteDevice.list(config); l.append(d); RemoteDevice.store(l, in: &config) }
            }
        Text("Die Geräteliste gilt im ganzen Haushalt. Koppeln muss jedes iPhone und iPad einmal selbst. Zum Entfernen nach links wischen.")
            .font(.footnote).foregroundColor(Theme.secondary)
    }
}
