import SwiftUI

// ============================================================
// Countdown-Bucket: "Noch 42 Tage bis Wien".
// Einstellungen: entries = [{ title, date (yyyy-MM-dd), emoji }]
// ============================================================
enum CountdownBucket {
    static let kind = BucketKind(
        id: "countdown", name: "Countdowns", symbol: "hourglass", tint: .purple, art: .glance,
        interests: ["organisation", "unterwegs", "freizeit"], blurb: "Tage bis zum Urlaub, Geburtstag oder zur Prüfung.",
        needsSetup: { ($0["entries"]?.array ?? []).isEmpty },
        glance: { inst, size in AnyView(CountdownGlance(config: inst.config, size: size)) },
        settings: { binding in AnyView(CountdownEditor(config: binding)) }
    )

    struct Entry: Identifiable, Equatable {
        var id = UUID()
        var title: String
        var date: Date
        var emoji: String
    }

    static let dayFormat: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    static func entries(_ config: [String: JSON]) -> [Entry] {
        (config["entries"]?.array ?? []).compactMap { j in
            guard let o = j.object, let t = o["title"]?.string, let ds = o["date"]?.string,
                  let d = dayFormat.date(from: ds) else { return nil }
            return Entry(title: t, date: d, emoji: o["emoji"]?.string ?? "⏳")
        }
    }

    static func store(_ list: [Entry], in config: inout [String: JSON]) {
        config["entries"] = .array(list.map { e in
            JSON.object(["title": .string(e.title), "date": .string(dayFormat.string(from: e.date)), "emoji": .string(e.emoji)])
        })
    }

    static func daysLeft(_ d: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
    }
}

struct CountdownGlance: View {
    let config: [String: JSON]
    let size: BucketSize
    @Environment(\.glanceSpace) private var space

    var body: some View {
        let all = CountdownBucket.entries(config)
            .filter { CountdownBucket.daysLeft($0.date) >= 0 }
            .sorted { $0.date < $1.date }
        // Nur einer, oder wenig Platz → der nächste groß. Sonst so viele Zeilen, wie passen,
        // und die Schrift wächst mit dem freien Platz.
        let rows = fitRows(space.height, row: 34)
        if all.isEmpty {
            Text("Noch keine Countdowns").foregroundColor(Theme.secondary)
        } else if all.count == 1 || rows < 3 || space.width < 220 {
            let e = all[0]
            let big = min(space.height * 0.42, 72)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.emoji).font(.system(size: big * 0.55))
                Text(label(CountdownBucket.daysLeft(e.date))).font(.system(size: big, weight: .semibold).monospacedDigit())
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text(e.title).font(.headline).foregroundColor(Theme.secondary).lineLimit(1)
                if all.count > 1 && space.height > 150 {
                    Text("+ \(all.count - 1) weitere").font(.footnote).foregroundColor(Theme.secondary)
                }
            }
        } else {
            let pages = Pages.split(all, height: space.height, row: 38)
            // Eine Seite: Zeilen wachsen mit dem Platz. Mehrere Seiten: feste Zeilenhöhe.
            // Wenige Einträge füllen die Karte ganz aus (kein leerer Streifen unten)
            let rowH = pages.count == 1 ? min(space.height / CGFloat(all.count), 96) : 38
            GlancePager(pages: pages) { list in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                    if i > 0 { Divider() }
                    HStack(spacing: 10) {
                        Text(e.emoji).font(.system(size: min(rowH * 0.45, 34)))
                        Text(e.title).font(rowH > 70 ? .title2 : rowH > 44 ? .title3 : .body).lineLimit(1)
                        Spacer()
                        Text(label(CountdownBucket.daysLeft(e.date)))
                            .font((rowH > 70 ? Font.title : rowH > 44 ? .title3 : .headline).weight(.semibold).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundColor(CountdownBucket.daysLeft(e.date) <= 7 ? Theme.accent : .primary)
                    }
                    .frame(height: max(0, rowH - 1))
                }
            }
            }
        }
    }

    private func label(_ d: Int) -> String { d == 0 ? "Heute" : d == 1 ? "Morgen" : "\(d) Tage" }
}

struct CountdownEditor: View {
    @Binding var config: [String: JSON]
    /// Index des Eintrags, der gerade bearbeitet wird (Einträge haben beim Lesen neue IDs → Index ist stabil)
    @State private var editing: Int?
    @State private var draft = CountdownBucket.Entry(title: "", date: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(), emoji: "✈️")

    var body: some View {
        let list = CountdownBucket.entries(config)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(list.enumerated()), id: \.offset) { i, e in
                if editing == i {
                    CountdownForm(entry: e, saveTitle: "Sichern",
                                  onSave: { new in var l = list; l[i] = new; CountdownBucket.store(l, in: &config); editing = nil },
                                  onCancel: { editing = nil },
                                  onDelete: { var l = list; l.remove(at: i); CountdownBucket.store(l, in: &config); editing = nil })
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(UIColor.tertiarySystemFill)))
                } else {
                    // Antippen öffnet die Bearbeitung direkt an Ort und Stelle
                    Button { withAnimation { editing = i } } label: {
                        HStack {
                            Text(e.emoji)
                            VStack(alignment: .leading) {
                                Text(e.title).foregroundColor(.primary)
                                Text(e.date, style: .date).font(.caption).foregroundColor(Theme.secondary)
                            }
                            Spacer()
                            Image(systemName: "pencil").foregroundColor(Theme.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("„\(e.title)“ bearbeiten")
                }
            }
            if editing == nil {
                if !list.isEmpty { Divider() }
                CountdownForm(entry: draft, saveTitle: "Countdown hinzufügen", onSave: { new in
                    var l = list; l.append(new); CountdownBucket.store(l, in: &config)
                    draft.title = ""
                })
                .id(list.count)   // Formular nach dem Hinzufügen leeren
            }
        }
    }
}

/// Titel, Symbol und Datum eines Countdowns – zum Anlegen und Bearbeiten.
struct CountdownForm: View {
    @State var entry: CountdownBucket.Entry
    let saveTitle: String
    let onSave: (CountdownBucket.Entry) -> Void
    var onCancel: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    private let emojis = ["✈️", "🎂", "🎓", "🎄", "🏖️", "🎉", "⚽️", "🎾", "❤️", "⏳"]
    private var valid: Bool { !entry.title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Wofür? z. B. Wien-Trip", text: $entry.title).textFieldStyle(.roundedBorder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(emojis, id: \.self) { em in
                        Text(em).font(.title2).padding(6)
                            .background(Circle().fill(em == entry.emoji ? Theme.accent.opacity(0.2) : Color.clear))
                            .onTapGesture { entry.emoji = em }
                    }
                }
            }
            DatePicker("Datum", selection: $entry.date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
            HStack {
                if let onDelete {
                    Button(role: .destructive, action: onDelete) { Label("Löschen", systemImage: "trash") }
                        .buttonStyle(.borderless)
                }
                Spacer()
                if let onCancel { Button("Abbrechen", action: onCancel).buttonStyle(.borderless) }
                Button {
                    var e = entry; e.title = e.title.trimmingCharacters(in: .whitespaces); onSave(e)
                } label: {
                    if onCancel == nil { Label(saveTitle, systemImage: "plus.circle.fill") }
                    else { Text(saveTitle).fontWeight(.semibold) }
                }
                .buttonStyle(.borderless)
                .disabled(!valid)
            }
        }
    }
}
