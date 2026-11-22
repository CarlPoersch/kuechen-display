import SwiftUI

// ============================================================
// „Neu in Hubert“: Kommt ein komplett neuer Bucket dazu, fragt Hubert
// beim Start einmal, ob er auf die Startseite soll (pro Gerät gemerkt).
// Neuen Bucket hier eintragen: ids + highlights.
// ============================================================

enum NewBuckets {
    /// Komplett neue Buckets (neueste zuerst)
    static let ids = ["sonne", "gaeste", "deals"]

    struct Highlight: Hashable { let symbol: String; let text: String }

    /// Drei kurze Punkte je Bucket für die Vorstellung
    static let highlights: [String: [Highlight]] = [
        "sonne": [
            Highlight(symbol: "sunrise.fill", text: "Auf- und Untergang, dazu die Sonnenbahn über den Tag – der Punkt zeigt, wo die Sonne gerade steht"),
            Highlight(symbol: "arrow.up.right", text: "Wie viel Licht dazukommt – und wie lange es noch bis zur Wintersonnenwende ist"),
            Highlight(symbol: "moonphase.waxing.gibbous", text: "Antippen: Goldene und Blaue Stunde, Mond und die Tageslänge übers Jahr"),
        ],
        "gaeste": [
            Highlight(symbol: "qrcode", text: "Runder Knopf unten rechts – Besuch tippt drauf und scannt den QR-Code"),
            Highlight(symbol: "camera", text: "Kamera aufs Handy, „Mit WLAN verbinden“ – kein Passwort abtippen"),
            Highlight(symbol: "ipad.and.iphone", text: "Pro Gerät ein- oder ausblenden, z. B. nur am Wand-iPad"),
        ],
        "deals": [
            Highlight(symbol: "square.grid.2x2", text: "Bereiche antippen – Mode, Streetwear, Schuhe, Make-up, Pflege, Parfum, Technik und mehr"),
            Highlight(symbol: "photo.on.rectangle", text: "Angebote mit Bild, Preis und Rabatt – je Suche eine eigene Reihe"),
            Highlight(symbol: "wand.and.stars", text: "Findet auch verwandte Wörter und Tippfehler (Kleider → Strickkleid)"),
        ],
    ]

    private static let key = "newBuckets.seen"
    static var seen: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    /// Was noch nicht gezeigt wurde und nicht schon auf der Startseite ist
    static func pending(_ store: AppStore) -> [BucketKind] {
        ids.filter { id in !seen.contains(id) && !store.buckets.contains { $0.bucket == id } }
            .compactMap { BucketRegistry.kind($0) }
    }

    static func markSeen(_ ids: [String]) { seen = seen.union(ids) }
}

/// Blatt mit den Neuheiten
struct NewBucketsSheet: View {
    let kinds: [BucketKind]
    let onClose: () -> Void
    @EnvironmentObject var store: AppStore
    @State private var added: [String: String] = [:]      // Bucket-Art → ID der neuen Karte

    /// Einstellungen der gerade hinzugefügten Karte direkt hier
    private func config(_ id: String) -> Binding<[String: JSON]> {
        Binding(get: { store.buckets.first { $0.id == id }?.config ?? [:] },
                set: { v in if let i = store.buckets.firstIndex(where: { $0.id == id }) { store.buckets[i].config = v } })
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    Text("Neu in Hubert").font(.largeTitle.weight(.bold)).padding(.top, 24)
                    ForEach(kinds) { k in
                        VStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LinearGradient(colors: [k.tint.opacity(0.85), k.tint], startPoint: .top, endPoint: .bottom))
                                .frame(width: 84, height: 84)
                                .overlay(Image(systemName: k.symbol).font(.system(size: 38, weight: .semibold)).foregroundColor(.white))
                            VStack(spacing: 6) {
                                Text(k.name).font(.title2.weight(.semibold))
                                Text(k.blurb).font(.body).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
                            }
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(NewBuckets.highlights[k.id] ?? [], id: \.self) { h in
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: h.symbol).font(.title3).foregroundColor(k.tint).frame(width: 30)
                                        Text(h.text).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .frame(maxWidth: 420, alignment: .leading)
                            if let id = added[k.id] {
                                Label("Auf deiner Startseite", systemImage: "checkmark.circle.fill")
                                    .font(.headline).foregroundColor(Theme.accent)
                                // Gleich einstellen (z. B. Bereiche bei Deals)
                                if let settings = k.settings {
                                    VStack(alignment: .leading, spacing: 14) { settings(config(id)) }
                                        .padding(16)
                                        .frame(maxWidth: 520)
                                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                                }
                            } else {
                                Button {
                                    store.addBucket(k)
                                    withAnimation { added[k.id] = store.buckets.last(where: { $0.bucket == k.id })?.id ?? "" }
                                } label: {
                                    Text("Zur Startseite hinzufügen").font(.headline).frame(maxWidth: 420).padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    Button(added.isEmpty ? "Nicht jetzt" : "Fertig") { onClose() }
                        .font(.body.weight(.semibold))
                        .padding(.bottom, 24)
                    Text("Du findest alles auch später unter Einstellungen → Bucket hinzufügen.")
                        .font(.footnote).foregroundColor(Theme.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

/// An die Startseite hängen: zeigt das Blatt einmal, sobald die Startseite geladen ist
struct NewBucketsPrompt: ViewModifier {
    @EnvironmentObject var store: AppStore
    @State private var kinds: [BucketKind] = []

    func body(content: Content) -> some View {
        content
            .task(id: store.buckets.isEmpty) {
                guard !store.buckets.isEmpty, kinds.isEmpty else { return }
                try? await Task.sleep(nanoseconds: 1_200_000_000)   // erst ankommen lassen
                kinds = NewBuckets.pending(store)
            }
            .sheet(isPresented: Binding(get: { !kinds.isEmpty }, set: { if !$0 { close() } })) {
                NewBucketsSheet(kinds: kinds, onClose: close).environmentObject(store)
            }
    }

    private func close() {
        NewBuckets.markSeen(kinds.map(\.id))
        kinds = []
        store.saveBuckets()     // auch beim Wegwischen: Einstellungen der neuen Karte sichern
    }
}
