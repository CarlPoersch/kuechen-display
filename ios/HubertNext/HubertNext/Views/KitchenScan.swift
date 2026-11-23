import SwiftUI
import AVFoundation
import Vision
import PhotosUI

// ============================================================
// Scannen für den Vorrat:
//  - Barcode: Kamera erkennt EAN/UPC, der Produktname kommt aus
//    Open Food Facts (freie Produktdatenbank, kein Konto nötig).
//  - Kassenzettel: Foto → Texterkennung auf dem Gerät (Vision) →
//    Artikelzeilen herausfiltern → prüfen → in den Vorrat.
// ============================================================

struct ScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Art", selection: $mode) {
                    Text("Barcode").tag(0)
                    Text("Kassenzettel").tag(1)
                }
                .pickerStyle(.segmented).padding()
                if mode == 0 { BarcodeScanView() } else { ReceiptScanView() }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Scannen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Barcode

struct BarcodeScanView: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var found: [Product] = []
    @State private var place = "Vorrat"
    @State private var lastCode = ""

    struct Product: Identifiable, Equatable {
        let id: String; var name: String; var detail: String; var added = false
        var suggested = ""   // Hubert's Vorschlag – weicht der Name ab, wird gelernt
    }

    var body: some View {
        VStack(spacing: 0) {
            CameraScanner { code in Task { await lookup(code) } }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.accent.opacity(0.6), lineWidth: 2).padding(50))
                .padding(.horizontal)
            List {
                Section {
                    Picker("Ablegen in", selection: $place) { ForEach(KitchenStore.places, id: \.self) { Text($0) } }
                } footer: {
                    Text("Barcode in den Rahmen halten. Jeder erkannte Artikel erscheint unten – mit einem Tipp in den Vorrat.")
                }
                if !found.isEmpty {
                    Section(header: Text("Erkannt")) {
                        ForEach($found) { $p in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    TextField("Name", text: $p.name).font(.headline)
                                    if !p.detail.isEmpty { Text(p.detail).font(.caption).foregroundColor(Theme.secondary) }
                                }
                                Spacer()
                                Button {
                                    if p.name != p.suggested { kitchen.learn(key: "EAN " + p.id, name: p.name) }
                                    kitchen.add("pantry", name: p.name, place: place); p.added = true
                                } label: {
                                    Image(systemName: p.added ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.title2).foregroundColor(p.added ? .green : Theme.accent)
                                }
                                .buttonStyle(.borderless).disabled(p.added)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    /// Produktname zum Barcode aus Open Food Facts
    private func lookup(_ code: String) async {
        guard code != lastCode, !found.contains(where: { $0.id == code }) else { return }
        lastCode = code
        var name = "Artikel \(code)", detail = "Nicht in der Produktdatenbank – Namen antippen und ändern"
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,product_name_de,brands,quantity")!
        var req = URLRequest(url: url); req.setValue("Hubert/1.0 (privat)", forHTTPHeaderField: "User-Agent")
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let p = obj["product"] as? [String: Any] {
            let n = (p["product_name_de"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (p["product_name"] as? String) ?? ""
            if !n.isEmpty {
                // Marke/Zusätze weg: "Gut & Günstig Haferflocken zart" → "Haferflocken"
                name = FoodNames.clean(n)
                detail = [n, p["brands"] as? String, p["quantity"] as? String].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            }
        }
        if let learned = kitchen.pantryName(barcode: code) { name = learned }
        withAnimation { found.insert(Product(id: code, name: name, detail: detail, suggested: name), at: 0) }
    }
}

/// Kamera mit Barcode-Erkennung (AVFoundation – läuft auch auf iOS 15)
struct CameraScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController(); c.onCode = onCode; return c
    }
    func updateUIViewController(_ c: ScannerController, context: Context) { c.onCode = onCode }

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var preview: AVCaptureVideoPreviewLayer?
        private var last: (String, Date)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            // async-Variante statt Rückruf: Der Rückruf käme auf einem Hintergrund-Thread an,
            // was bei standardmäßiger MainActor-Zuordnung die App beendet (Absturz beim Antippen).
            Task { @MainActor in
                let ok = await AVCaptureDevice.requestAccess(for: .video)
                ok ? self.setup() : self.denied()
            }
        }

        private func setup() {
            guard let cam = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: cam),
                  session.canAddInput(input) else { denied(); return }
            session.addInput(input)
            let out = AVCaptureMetadataOutput()
            guard session.canAddOutput(out) else { return }
            session.addOutput(out)
            out.setMetadataObjectsDelegate(self, queue: .main)
            out.metadataObjectTypes = [.ean13, .ean8, .upce, .code128].filter { out.availableMetadataObjectTypes.contains($0) }
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            preview = layer
            let s = session
            DispatchQueue.global(qos: .userInitiated).async { @Sendable in s.startRunning() }
        }

        private func denied() {
            let l = UILabel()
            l.text = "Kamera nicht erlaubt.\nEinstellungen → Hubert → Kamera"
            l.numberOfLines = 0; l.textAlignment = .center; l.textColor = .white
            l.frame = view.bounds; l.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(l)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview?.frame = view.bounds
            if let c = preview?.connection, c.isVideoOrientationSupported {
                switch view.window?.windowScene?.interfaceOrientation {
                case .landscapeLeft: c.videoOrientation = .landscapeLeft
                case .landscapeRight: c.videoOrientation = .landscapeRight
                case .portraitUpsideDown: c.videoOrientation = .portraitUpsideDown
                default: c.videoOrientation = .portrait
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            let s = session
            DispatchQueue.global(qos: .userInitiated).async { @Sendable in s.stopRunning() }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let code = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
            // Denselben Code nicht mehrfach pro Sekunde melden
            if let l = last, l.0 == code, Date().timeIntervalSince(l.1) < 3 { return }
            last = (code, Date())
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCode?(code)
        }
    }
}

// MARK: Kassenzettel

struct ReceiptScanView: View {
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var image: UIImage?
    @State private var lines: [Line] = []
    @State private var place = "Vorrat"
    @State private var busy = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var done: Int?

    struct Line: Identifiable {
        let id = UUID()
        let raw: String          // so stand es auf dem Kassenzettel
        let suggested: String    // Hubert's Vorschlag
        var name: String
        var on = true
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        SoftButton(title: "Foto machen", symbol: "camera.fill", primary: true) { showCamera = true }
                    }
                    SoftButton(title: "Aus Fotos", symbol: "photo") { showLibrary = true }
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            } footer: {
                Text("Kassenzettel flach und gut beleuchtet fotografieren. Die Texterkennung läuft auf dem Gerät.")
            }
            if busy { Section { HStack { ProgressView(); Text("Lese Kassenzettel …").padding(.leading, 8) } } }
            if !lines.isEmpty {
                Section(header: Text("Gefundene Artikel · \(lines.filter { $0.on }.count) ausgewählt"),
                        footer: Text("Oben steht, was auf dem Kassenzettel steht, darunter Huberts Vorschlag. Änderst du einen Namen, merkt sich Hubert das für den ganzen Haushalt.")) {
                    ForEach($lines) { $l in
                        HStack {
                            Button { l.on.toggle() } label: {
                                Image(systemName: l.on ? "checkmark.circle.fill" : "circle").font(.title3)
                                    .foregroundColor(l.on ? Theme.accent : Color(UIColor.tertiaryLabel))
                            }
                            .buttonStyle(.borderless)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.raw.uppercased() + "  →").font(.caption.monospaced()).foregroundColor(Theme.secondary).lineLimit(1)
                                TextField("Name", text: $l.name).font(.headline).foregroundColor(l.on ? .primary : Theme.secondary)
                            }
                        }
                    }
                    Picker("Ablegen in", selection: $place) { ForEach(KitchenStore.places, id: \.self) { Text($0) } }
                    Button {
                        let picked = lines.filter { $0.on }
                        // Korrekturen lernen
                        for l in picked where l.name != l.suggested { kitchen.learn(key: FoodNames.key(l.raw), name: l.name) }
                        let chosen = picked.map { $0.name }
                        for n in chosen {
                            if !kitchen.hasInPantry(exact: n) { kitchen.add("pantry", name: n, place: place) }
                            // Passendes auf der Einkaufsliste gleich abhaken
                            for it in kitchen.shop where !it.done && KitchenStore.key(n).contains(KitchenStore.key(it.name)) {
                                kitchen.toggle(it)
                            }
                        }
                        done = chosen.count; lines = []; image = nil
                    } label: {
                        Label("\(lines.filter { $0.on }.count) Artikel in den Vorrat", systemImage: "archivebox.fill").font(.headline)
                    }
                    .disabled(!lines.contains { $0.on })
                }
            } else if image != nil && !busy {
                Section { Text("Keine Artikelzeilen erkannt. Bitte ein schärferes Foto versuchen.").foregroundColor(Theme.secondary) }
            }
            if let n = done {
                Section { Label("\(n) Artikel im Vorrat. Passende Einträge auf der Einkaufsliste sind abgehakt.", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green) }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showCamera) { CameraPicker { img in read(img) }.ignoresSafeArea() }
        .sheet(isPresented: $showLibrary) { LibraryPicker { img in read(img) } }
    }

    private func read(_ img: UIImage) {
        image = img; busy = true; done = nil; lines = []
        Receipt.recognize(img) { raws in
            busy = false
            var seen = Set<String>()
            lines = raws.compactMap { raw in
                let n = kitchen.pantryName(receipt: raw)
                guard !seen.contains(n.lowercased()) else { return nil }   // dieselbe Sache nur einmal
                seen.insert(n.lowercased())
                return Line(raw: raw, suggested: n, name: n)
            }
        }
    }
}

enum Receipt {
    /// Text erkennen und Artikelzeilen herausfiltern
    static func recognize(_ image: UIImage, done: @escaping ([String]) -> Void) {
        guard let cg = image.cgImage else { done([]); return }
        // @Sendable: Vision ruft das im Hintergrund auf
        let req = VNRecognizeTextRequest { @Sendable req, _ in
            let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
            let names = parse(rows(obs))
            Task { @MainActor in done(names) }
        }
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        if let langs = try? req.supportedRecognitionLanguages(), langs.contains("de-DE") { req.recognitionLanguages = ["de-DE"] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        DispatchQueue.global(qos: .userInitiated).async { @Sendable in
            try? VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([req])
        }
    }

    /// Kassenzettel haben Name links und Preis rechts als getrennte Textstücke → nach Höhe zu Zeilen zusammenfügen
    nonisolated static func rows(_ obs: [VNRecognizedTextObservation]) -> [String] {
        let pieces = obs.compactMap { o -> (CGRect, String)? in
            guard let t = o.topCandidates(1).first?.string else { return nil }
            return (o.boundingBox, t)
        }.sorted { $0.0.midY > $1.0.midY }
        var rows: [[(CGRect, String)]] = []
        for p in pieces {
            if let last = rows.last?.first, abs(last.0.midY - p.0.midY) < max(last.0.height, p.0.height) * 0.6 {
                rows[rows.count - 1].append(p)
            } else { rows.append([p]) }
        }
        return rows.map { $0.sorted { $0.0.minX < $1.0.minX }.map { $0.1 }.joined(separator: " ") }
    }

    nonisolated private static let skip = ["SUMME", "ZU ZAHLEN", "MWST", "MW-ST", "NETTO", "BRUTTO", "GESAMT", "BAR", "KARTE", "GEGEBEN",
                               "RÜCKGELD", "RUECKGELD", "EC-", "VISA", "MASTERCARD", "PFAND", "RABATT", "TOTAL", "STEUER", "ZWISCHENSUMME",
                               "BON", "KASSE", "DATUM", "UHRZEIT", "TSE", "PAYBACK", "COUPON", "EUR ", "GIROCARD", "KUNDENBELEG",
                               "TERMINAL", "TRANS", "BELEG", "DANKE", "FILIALE", "STEUERNR", "UST", "SIGNATUR"]

    nonisolated static func parse(_ rows: [String]) -> [String] {
        let price = try! NSRegularExpression(pattern: #"-?\d+[,.]\d{2}\s*(?:€|EUR)?\s*[A-Z*]?\s*$"#)
        var out: [String] = []
        for row in rows {
            let up = row.uppercased()
            // Ganze Wörter vergleichen ("BAR" soll nicht "BARILLA" treffen)
            let words = Set(up.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
            if skip.contains(where: { $0.contains(" ") || $0.hasSuffix("-") ? up.contains($0) : words.contains($0) }) { continue }
            let ns = row as NSString
            guard let m = price.firstMatch(in: row, range: NSRange(location: 0, length: ns.length)) else { continue }
            if ns.substring(with: m.range).hasPrefix("-") { continue }       // Rabatte, Pfand zurück
            var name = ns.substring(to: m.range.location)
            // "2 x 1,29" und reine Zahlen entfernen
            name = name.replacingOccurrences(of: #"\d+\s*[xX]\s*\d+[,.]\d{2}"#, with: "", options: .regularExpression)
            name = name.replacingOccurrences(of: #"^\s*\d+\s*[xX]?\s+"#, with: "", options: .regularExpression)
            name = name.replacingOccurrences(of: #"\s\d+[,.]?\d*\s*$"#, with: "", options: .regularExpression)
            name = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard name.count >= 3, name.rangeOfCharacter(from: .letters) != nil else { continue }
            if !out.contains(name) { out.append(name) }   // Rohtext; Bereinigung macht FoodNames
        }
        return out
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Foto mit der Kamera aufnehmen
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ p: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// Foto aus der Mediathek wählen (braucht keine Foto-Erlaubnis)
struct LibraryPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(); cfg.filter = .images; cfg.selectionLimit = 1
        let p = PHPickerViewController(configuration: cfg); p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ p: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LibraryPicker
        init(_ p: LibraryPicker) { parent = p }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
            let deliver = parent.onImage
            item.loadObject(ofClass: UIImage.self) { @Sendable obj, _ in
                if let img = obj as? UIImage { Task { @MainActor in deliver(img) } }
            }
        }
    }
}
