import SwiftUI

// ============================================================
// Smart Home: Lampen an Tuya-WLAN-Steckdosen (z. B. HBN / Smart Life) schalten.
// Widget: große Kacheln, ein Tipp schaltet. App: Liste mit Schaltern, „Alle aus“.
// Einrichtung einmal über „Mit Tuya verbinden“ in den Einstellungen.
// Design: docs/specs/2026-11-24-smart-home-design.md
// ============================================================

enum SmartHomeBucket {
    static let kind = BucketKind(
        id: "smarthome", name: "Smart Home", symbol: "lightbulb.fill", tint: .yellow, art: .glance,
        interests: ["haushalt", "technik"], blurb: "Lampen an WLAN-Steckdosen schalten – direkt im WLAN, ohne Wartezeit.",
        glance: { _, _ in AnyView(SmartHomeGlance()) },
        detail: { _ in AnyView(SmartHomeView()) },
        itemLinks: true,
        settings: { binding in AnyView(SmartHomeSettings(config: binding)) }
    )
}

// MARK: Kachel

struct SmartLightTile: View {
    let light: SmartLight
    /// kompakt = eine Zeile (Symbol links, Name rechts) für schmale Karten (iPhone)
    var compact = false
    @ObservedObject private var store = SmartHomeStore.shared

    static func height(compact: Bool) -> CGFloat { compact ? 58 : 92 }

    var body: some View {
        let on = store.isOn(light) == true
        let reachable = store.isReachable(light)
        let symbol = !reachable ? "lightbulb.slash" : on ? "lightbulb.fill" : "lightbulb"
        let status = !reachable ? "Nicht erreichbar" : store.isOn(light) == nil ? "…" : on ? "An" : "Aus"
        Button { store.toggle(light) } label: {
            Group {
                if compact {
                    HStack(spacing: 10) {
                        Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                            .foregroundColor(on && reachable ? .yellow : Theme.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(light.name).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text(status).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: symbol).font(.system(size: 24, weight: .semibold))
                            .foregroundColor(on && reachable ? .yellow : Theme.secondary)
                        Spacer(minLength: 8)
                        Text(light.name).font(.body.weight(.semibold)).foregroundColor(.primary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text(status).font(.footnote).foregroundColor(Theme.secondary).lineLimit(1)
                    }
                    .padding(14)
                }
            }
            // Mindesthöhe statt fester Höhe: bei größerer Schrift wächst die Kachel mit, statt abzuschneiden
            .frame(maxWidth: .infinity, minHeight: Self.height(compact: compact), alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(on && reachable ? Color.yellow.opacity(0.22) : Color(UIColor.tertiarySystemFill)))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(store.busy.contains(light.id) ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(light.name), \(status)")
        .accessibilityHint("Zum Umschalten tippen")
    }
}

// MARK: Karte auf der Startseite

struct SmartHomeGlance: View {
    @EnvironmentObject var app: AppStore
    @ObservedObject private var store = SmartHomeStore.shared
    @Environment(\.glanceSpace) private var space
    @Environment(\.editBucket) private var editBucket
    @Environment(\.openBucketDetail) private var openDetail

    private let gap: CGFloat = 10

    var body: some View {
        let lights = store.lights
        Group {
            if lights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.loaded || store.devices.isEmpty ? "Noch keine Lampen" : "Lädt …").font(.headline)
                    Text("Einmal mit Tuya (Smart Life) verbinden – dann schaltest du deine Steckdosen hier.")
                        .font(.subheadline).foregroundColor(Theme.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { editBucket() } label: {
                        Text("Einrichten").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            .padding(.horizontal, 16).frame(minHeight: 36)
                            .background(Capsule().fill(Theme.accent))
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                // Schmale Karte (iPhone, halbe Breite): einzeilige Kacheln, zwei nebeneinander.
                // Breite Karte (iPad): große Kacheln, so viele nebeneinander, wie Lampen da sind
                // (mind. 160 pt breit) – wenige Lampen werden also breiter statt winzig.
                let compact = space.width < 520
                let minWidth: CGFloat = compact ? 140 : 160
                let maxCols = max(1, Int((space.width + gap) / (minWidth + gap)))
                let cols = max(1, min(maxCols, lights.count))
                let h = SmartLightTile.height(compact: compact)
                let rows = max(1, Int((space.height + gap) / (h + gap)))
                let room = cols * rows
                let shown = lights.count > room ? Array(lights.prefix(room - 1)) : lights
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: cols), spacing: gap) {
                    ForEach(shown) { SmartLightTile(light: $0, compact: compact) }
                    if lights.count > room {
                        Button { openDetail() } label: {
                            VStack(spacing: 2) {
                                Text("+\(lights.count - shown.count)").font(.title3.weight(.semibold))
                                Text("weitere").font(.caption).foregroundColor(Theme.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: h)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .refreshing(id: app.household?.id ?? "", every: { 15 }) {
            await SmartHomeStore.shared.refresh(household: app.household?.id)
        }
    }
}

// MARK: App

struct SmartHomeView: View {
    @EnvironmentObject var app: AppStore
    @ObservedObject private var store = SmartHomeStore.shared
    @State private var renaming: SmartLight?
    @State private var setup = false

    var body: some View {
        List {
            if store.lights.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Noch keine Lampen").font(.headline)
                        Text("Verbinde Hubert einmal mit deinem Tuya-Konto. Danach schaltest du die Steckdosen direkt im WLAN.")
                            .font(.subheadline).foregroundColor(Theme.secondary)
                    }
                    .padding(.vertical, 4)
                    Button { setup = true } label: { Label("Mit Tuya verbinden", systemImage: "link") }
                }
            } else {
                Section {
                    ForEach(store.lights) { l in row(l) }
                }
                Section {
                    Button { store.allOff() } label: {
                        Label("Alle aus", systemImage: "lightbulb.slash").font(.body.weight(.semibold))
                    }
                    .disabled(!store.lights.contains { store.isOn($0) == true })
                }
                Section {
                    if store.searching {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Suche Steckdosen im WLAN …").foregroundColor(Theme.secondary)
                        }
                    } else {
                        Button { Task { await store.locate() } } label: { Label("Im WLAN suchen", systemImage: "wifi") }
                    }
                } footer: {
                    Text("Geschaltet wird direkt im WLAN – nur zu Hause. Umbenennen: Eintrag gedrückt halten.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.refresh(household: app.household?.id) }
        .refreshing(id: app.household?.id ?? "", every: { 15 }) {
            await SmartHomeStore.shared.refresh(household: app.household?.id)
        }
        .sheet(item: $renaming) { l in SmartRenameSheet(light: l) }
        .sheet(isPresented: $setup) { SmartHomeSetupSheet(household: app.household?.id ?? "") }
        .alert(store.message ?? "", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func row(_ l: SmartLight) -> some View {
        let reachable = store.isReachable(l)
        let on = store.isOn(l) == true
        return HStack(spacing: 14) {
            Image(systemName: !reachable ? "lightbulb.slash" : on ? "lightbulb.fill" : "lightbulb")
                .font(.title3).foregroundColor(on && reachable ? .yellow : Theme.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.name).lineLimit(1)
                if !reachable { Text("Nicht erreichbar").font(.caption).foregroundColor(Theme.secondary) }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { store.isOn(l) == true },
                                     set: { v in if v != (store.isOn(l) == true) { store.toggle(l) } }))
                .labelsHidden()
                .tint(Theme.accent)
                .disabled(!reachable && store.isOn(l) == nil)
        }
        .frame(minHeight: 48)
        .contextMenu {
            Button { renaming = l } label: { Label("Umbenennen", systemImage: "pencil") }
        }
        .swipeActions(edge: .trailing) {
            Button { renaming = l } label: { Label("Umbenennen", systemImage: "pencil") }.tint(Theme.accent)
        }
    }
}

struct SmartRenameSheet: View {
    let light: SmartLight
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                Text("Gilt nur in Hubert – in Smart Life bleibt der Name, wie er ist.")
                    .font(.footnote).foregroundColor(Theme.secondary)
            }
            .navigationTitle("Umbenennen").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { SmartHomeStore.shared.rename(light, to: name); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { name = light.name }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Einstellungen

struct SmartHomeSettings: View {
    @Binding var config: [String: JSON]
    @EnvironmentObject var app: AppStore
    @ObservedObject private var store = SmartHomeStore.shared
    @State private var setup = false
    @State private var manual = false
    @State private var reloading = false
    @State private var note: String?

    var body: some View {
        let count = store.lights.count
        if count > 0 {
            Label(count == 1 ? "1 Lampe" : "\(count) Lampen", systemImage: "lightbulb.fill")
        }
        if let saved = SmartHomeStore.savedCredentials, let hid = app.household?.id {
            Button {
                reloading = true; note = nil
                Task {
                    do {
                        let n = try await store.importFromCloud(accessId: saved.accessId, secret: saved.secret,
                                                                region: TuyaRegion(rawValue: saved.region) ?? .centralEurope, household: hid)
                        note = n == 1 ? "1 Lampe geladen." : "\(n) Lampen geladen."
                    } catch {
                        note = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    }
                    reloading = false
                }
            } label: {
                HStack {
                    Label("Geräte neu laden", systemImage: "arrow.clockwise")
                    if reloading { Spacer(); ProgressView() }
                }
            }
            .disabled(reloading)
        }
        Button { setup = true } label: {
            Label(SmartHomeStore.savedCredentials == nil ? "Mit Tuya verbinden" : "Tuya-Zugang ändern", systemImage: "link")
        }
        if count > 0 {
            Button { manual = true } label: { Label("Adressen von Hand eintragen", systemImage: "number") }
        }
        if let n = note { Text(n).font(.footnote).foregroundColor(Theme.secondary) }
        Text("Die Lampen gelten im ganzen Haushalt. Deine Tuya-Zugangsdaten bleiben nur auf diesem Gerät.")
            .font(.footnote).foregroundColor(Theme.secondary)
            .sheet(isPresented: $setup) { SmartHomeSetupSheet(household: app.household?.id ?? "") }
            .sheet(isPresented: $manual) { SmartIPSheet() }
    }
}

/// Einmalige Einrichtung: Zugangsdaten aus dem Tuya-Entwicklerportal eingeben
struct SmartHomeSetupSheet: View {
    let household: String
    @ObservedObject private var store = SmartHomeStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var accessId = ""
    @State private var secret = ""
    @State private var region: TuyaRegion = .centralEurope
    @State private var working = false
    @State private var error: String?
    @State private var done: Int?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    step(1, "Im Tuya-Portal unter **Cloud** ein Projekt anlegen (Methode „Smart Home“, Rechenzentrum passend zu deinem Smart-Life-Konto).")
                    step(2, "Im Projekt **Devices → Link App Account → Add App Account** und den QR-Code in Smart Life scannen (Ich → Scan-Symbol oben rechts).")
                    step(3, "Unter **Overview** stehen Access ID und Access Secret – hier eintragen.")
                } header: { Text("So geht’s") }

                Section {
                    Picker("Rechenzentrum", selection: $region) {
                        ForEach(TuyaRegion.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Access ID", text: $accessId)
                        .textInputAutocapitalization(.never).disableAutocorrection(true)
                    SecureField("Access Secret", text: $secret)
                        .textInputAutocapitalization(.never).disableAutocorrection(true)
                } header: { Text("Tuya-Zugang") } footer: {
                    Text("Die Zugangsdaten bleiben im Schlüsselbund dieses Geräts. Hubert braucht sie nur zum Laden der Steckdosen – geschaltet wird ohne Cloud.")
                }

                Section {
                    Button { connect() } label: {
                        HStack {
                            Text(working ? "Verbinde …" : "Verbinden").font(.body.weight(.semibold))
                            if working { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(working || household.isEmpty || accessId.trimmingCharacters(in: .whitespaces).isEmpty
                              || secret.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let e = error { Text(e).font(.footnote).foregroundColor(.red) }
                    if let n = done {
                        Label(n == 1 ? "1 Lampe gefunden. Hubert sucht sie jetzt im WLAN." : "\(n) Lampen gefunden. Hubert sucht sie jetzt im WLAN.",
                              systemImage: "checkmark.circle.fill").foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Mit Tuya verbinden").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(done == nil ? "Abbrechen" : "Fertig") { dismiss() } }
            }
            .onAppear {
                if let s = SmartHomeStore.savedCredentials {
                    accessId = s.accessId; secret = s.secret
                    region = TuyaRegion(rawValue: s.region) ?? .centralEurope
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.subheadline.weight(.bold)).foregroundColor(.white)
                .frame(width: 22, height: 22).background(Circle().fill(Theme.accent))
            Text(text).font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func connect() {
        working = true; error = nil; done = nil
        Task {
            do {
                done = try await store.importFromCloud(accessId: accessId, secret: secret, region: region, household: household)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            working = false
        }
    }
}

/// Ersatz, falls die Suche nichts findet: IP-Adresse je Steckdose eintragen
struct SmartIPSheet: View {
    @ObservedObject private var store = SmartHomeStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var ips: [String: String] = [:]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ForEach(store.devices) { d in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.name).font(.subheadline.weight(.semibold))
                            TextField("z. B. 192.168.178.40", text: Binding(get: { ips[d.id] ?? d.ip }, set: { ips[d.id] = $0 }))
                                .keyboardType(.decimalPad)
                        }
                    }
                } footer: {
                    Text("Die Adresse steht in deinem Router (z. B. FRITZ!Box → Heimnetz). Am besten dort „Immer die gleiche IP-Adresse“ einschalten.")
                }
            }
            .navigationTitle("Adressen").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        for (id, ip) in ips { store.setIP(id, ip) }
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
