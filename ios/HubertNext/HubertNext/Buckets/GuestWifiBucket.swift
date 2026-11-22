import SwiftUI
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

// ============================================================
// Gäste-WLAN: runder Knopf unten rechts auf der Startseite.
// Antippen → großer QR-Code; Besuch richtet die Kamera darauf und ist im WLAN.
// Pro Gerät ein- oder ausblendbar (z. B. am Wand-iPad immer, am iPhone nicht):
// lange drücken → „Auf diesem iPhone ausblenden“, wieder einblenden in den
// Einstellungen des Buckets.
// Warum QR nach dem WIFI:-Standard: iPhone- und Android-Kamera erkennen ihn
// direkt und bieten „Mit WLAN verbinden“ an – ohne App.
// ============================================================

enum GuestWifiBucket {
    static let kind = BucketKind(
        id: "gaeste", name: "Gäste-WLAN", symbol: "wifi", tint: .blue, art: .button,
        interests: ["haushalt"], blurb: "Runder Knopf unten rechts: Besuch tippt drauf, scannt den QR-Code und ist im WLAN.",
        needsSetup: { ($0["ssid"]?.string ?? "").isEmpty },
        detail: { inst in AnyView(GuestWifiSheet(config: inst.config)) },
        settings: { binding in AnyView(GuestWifiSettings(config: binding)) }
    )

    enum Security: String, CaseIterable, Identifiable {
        case wpa = "WPA", wep = "WEP", open = "nopass"
        var id: String { rawValue }
        var label: String { self == .wpa ? "WPA2/WPA3" : self == .wep ? "WEP (alt)" : "Ohne Passwort" }
    }

    static func ssid(_ c: [String: JSON]) -> String { c["ssid"]?.string ?? "" }
    static func password(_ c: [String: JSON]) -> String { c["password"]?.string ?? "" }
    static func security(_ c: [String: JSON]) -> Security { Security(rawValue: c["security"]?.string ?? "") ?? .wpa }
    static func hidden(_ c: [String: JSON]) -> Bool { c["hidden"]?.bool ?? false }

    /// Text im QR-Code, z. B. WIFI:T:WPA;S:Zuhause;P:geheim;;
    static func payload(_ c: [String: JSON]) -> String {
        // Sonderzeichen müssen mit \ maskiert werden, sonst bricht der Name/das Passwort ab
        func esc(_ s: String) -> String {
            var out = ""
            for ch in s { if "\\;,:\"".contains(ch) { out.append("\\") }; out.append(ch) }
            return out
        }
        let sec = security(c)
        var s = "WIFI:T:\(sec.rawValue);S:\(esc(ssid(c)));"
        if sec != .open { s += "P:\(esc(password(c)));" }
        if hidden(c) { s += "H:true;" }
        return s + ";"
    }

    /// QR-Code als scharfes Bild (ohne Weichzeichnen vergrößert)
    static func qr(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Der runde Knopf unten rechts auf der Startseite
struct GuestWifiButton: View {
    @EnvironmentObject var store: AppStore
    let instance: BucketInstance
    @State private var showQR = false
    @State private var editing = false

    var body: some View {
        let big = UIDevice.current.userInterfaceIdiom == .pad
        Button { if GuestWifiBucket.ssid(instance.config).isEmpty { editing = true } else { showQR = true } } label: {
            Image(systemName: "qrcode").font(.system(size: big ? 26 : 22, weight: .semibold)).foregroundColor(.white)
                .frame(width: big ? 66 : 58, height: big ? 66 : 58)
                .background(Circle().fill(Theme.accent))
                .overlay(alignment: .topTrailing) {
                    // kleines WLAN-Zeichen, damit Besuch sofort versteht, wofür der Knopf ist
                    Image(systemName: "wifi").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.accent)
                        .frame(width: 22, height: 22).background(Circle().fill(Theme.card))
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        .offset(x: 2, y: -2)
                }
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gäste-WLAN – QR-Code zeigen")
        .contextMenu {
            Button { showQR = true } label: { Label("QR-Code zeigen", systemImage: "qrcode") }
            Button { editing = true } label: { Label("WLAN ändern", systemImage: "slider.horizontal.3") }
            Button { let id = instance.id; withAnimation { store.setHidden(id, true) } } label: {
                Label("Auf diesem " + AppStore.deviceName + " ausblenden", systemImage: "eye.slash")
            }
        }
        .sheet(isPresented: $showQR) { GuestWifiSheet(config: instance.config) }
        .sheet(isPresented: $editing) { BucketEditSheet(bucketId: instance.id).environmentObject(store) }
    }
}

/// Blatt mit dem großen QR-Code – für den Besuch gemacht
struct GuestWifiSheet: View {
    let config: [String: JSON]
    @Environment(\.dismiss) private var dismiss
    @State private var showPassword = false
    @State private var copied = false
    @State private var before: CGFloat = 0.5

    var body: some View {
        let sec = GuestWifiBucket.security(config)
        let pw = GuestWifiBucket.password(config)
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("Willkommen! 👋").font(.title.weight(.bold))
                        Text("Kamera aufs Handy öffnen, auf den Code richten und „Mit WLAN verbinden“ tippen.")
                            .font(.subheadline).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    if let img = GuestWifiBucket.qr(GuestWifiBucket.payload(config)) {
                        Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
                            .frame(maxWidth: 320)
                            .padding(18)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
                            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                            .accessibilityLabel("QR-Code für das WLAN \(GuestWifiBucket.ssid(config))")
                    }

                    // Für Geräte ohne Kamera-Erkennung: Name und Passwort zum Abtippen
                    VStack(spacing: 0) {
                        row("WLAN", GuestWifiBucket.ssid(config), symbol: "wifi")
                        if sec != .open {
                            Divider().padding(.leading, 52)
                            Button { withAnimation { showPassword.toggle() } } label: {
                                row("Passwort", showPassword ? pw : String(repeating: "•", count: min(12, max(8, pw.count))),
                                    symbol: "key.fill", hint: showPassword ? nil : "Zeigen")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))

                    if sec != .open && UIDevice.current.userInterfaceIdiom == .phone {
                        Button {
                            UIPasteboard.general.string = pw
                            withAnimation { copied = true }
                        } label: {
                            Label(copied ? "Passwort kopiert" : "Passwort kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.body.weight(.semibold)).foregroundColor(Theme.accent)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Gäste-WLAN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        // QR gut scannbar: kurz heller, danach wie vorher
        .onAppear { before = UIScreen.main.brightness; UIScreen.main.brightness = max(before, 0.8) }
        .onDisappear { UIScreen.main.brightness = before }
    }

    private func row(_ title: String, _ value: String, symbol: String, hint: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundColor(Theme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(Theme.secondary)
                Text(value).font(.title3.weight(.semibold).monospaced()).lineLimit(1).minimumScaleFactor(0.6)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            if let h = hint { Text(h).font(.subheadline).foregroundColor(Theme.accent) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// Einstellungen: Netzname, Passwort, Verschlüsselung
struct GuestWifiSettings: View {
    @Binding var config: [String: JSON]
    @State private var reveal = false

    private var security: Binding<GuestWifiBucket.Security> {
        Binding(get: { GuestWifiBucket.security(config) }, set: { config["security"] = .string($0.rawValue) })
    }

    var body: some View {
        TextField("Netzname (SSID)", text: $config.string("ssid"))
            .textInputAutocapitalization(.never).disableAutocorrection(true)
        if GuestWifiBucket.security(config) != .open {
            HStack {
                Group {
                    if reveal { TextField("Passwort", text: $config.string("password")) }
                    else { SecureField("Passwort", text: $config.string("password")) }
                }
                .textInputAutocapitalization(.never).disableAutocorrection(true)
                Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(reveal ? "Passwort verbergen" : "Passwort zeigen")
            }
        }
        Picker("Verschlüsselung", selection: security) {
            ForEach(GuestWifiBucket.Security.allCases) { Text($0.label).tag($0) }
        }
        Toggle("Verstecktes Netz", isOn: Binding(get: { GuestWifiBucket.hidden(config) }, set: { config["hidden"] = .bool($0) }))
            .tint(Theme.accent)
        Text("Tipp: Am besten ein eigenes Gäste-Netz im Router anlegen. Den Knopf blendest du pro Gerät ein oder aus – lange drücken.")
            .font(.caption).foregroundColor(Theme.secondary)
    }
}
