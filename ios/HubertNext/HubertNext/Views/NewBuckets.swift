import SwiftUI

// ============================================================
// „Neu in Hubert“: Kommt ein komplett neuer Bucket dazu, fragt Hubert
// beim Start einmal, ob er auf die Startseite soll (pro Gerät gemerkt).
// Neuen Bucket hier eintragen: ids + highlights.
// ============================================================

enum NewBuckets {
    /// Komplett neue Buckets (neueste zuerst)
    static let ids = ["deals"]

    struct Highlight: Hashable { let symbol: String; let text: String }

    /// Drei kurze Punkte je Bucket für die Vorstellung
    static let highlights: [String: [Highlight]] = [
        "deals": [
            Highlight(symbol: "text.magnifyingglass", text: "Stichwörter wie „Kopfhörer“, „Kaffee“ oder „Lego“ – eigene und fertige Vorschläge"),
            Highlight(symbol: "wand.and.stars", text: "Passt auch bei Tippfehlern, Mehrzahl und Synonymen (Kopfhörer → AirPods)"),
            Highlight(symbol: "eurosign.circle", text: "Höchstpreis je Stichwort und Black-Week-Countdown"),
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
    let onAdd: (BucketKind) -> Void
    let onClose: () -> Void
    @State private var added: Set<String> = []

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
                            Button {
                                withAnimation { _ = added.insert(k.id) }
                                onAdd(k)
                            } label: {
                                Text(added.contains(k.id) ? "Hinzugefügt" : "Zur Startseite hinzufügen")
                                    .font(.headline).frame(maxWidth: 420).padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .disabled(added.contains(k.id))
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
                NewBucketsSheet(kinds: kinds, onAdd: { store.addBucket($0) }, onClose: close)
            }
    }

    private func close() {
        NewBuckets.markSeen(kinds.map(\.id))
        kinds = []
    }
}
