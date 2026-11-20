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

    var body: some View {
        let list = CountdownBucket.entries(config)
            .filter { CountdownBucket.daysLeft($0.date) >= 0 }
            .sorted { $0.date < $1.date }
            .prefix(size == .s ? 1 : size == .m ? 3 : 6)
        if list.isEmpty {
            Text("Noch keine Countdowns").foregroundColor(Theme.secondary)
        } else if size == .s, let e = list.first {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.emoji).font(.title2)
                Text(label(CountdownBucket.daysLeft(e.date))).font(.system(size: 34, weight: .semibold)).minimumScaleFactor(0.6)
                Text(e.title).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(list)) { e in
                    HStack {
                        Text(e.emoji)
                        Text(e.title).lineLimit(1)
                        Spacer()
                        Text(label(CountdownBucket.daysLeft(e.date))).font(.headline.monospacedDigit())
                    }
                }
            }
        }
    }

    private func label(_ d: Int) -> String { d == 0 ? "Heute" : d == 1 ? "Morgen" : "\(d) Tage" }
}

struct CountdownEditor: View {
    @Binding var config: [String: JSON]
    @State private var title = ""
    @State private var emoji = "✈️"
    @State private var date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    private let emojis = ["✈️", "🎂", "🎓", "🎄", "🏖️", "🎉", "⚽️", "🎾", "❤️", "⏳"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(CountdownBucket.entries(config)) { e in
                HStack {
                    Text(e.emoji)
                    VStack(alignment: .leading) {
                        Text(e.title)
                        Text(e.date, style: .date).font(.caption).foregroundColor(Theme.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) { remove(e) } label: { Image(systemName: "minus.circle.fill") }
                        .buttonStyle(.borderless)
                }
            }
            Divider()
            TextField("Wofür? z. B. Wien-Trip", text: $title).textFieldStyle(.roundedBorder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(emojis, id: \.self) { em in
                        Text(em).font(.title2).padding(6)
                            .background(Circle().fill(em == emoji ? Theme.accent.opacity(0.2) : Color.clear))
                            .onTapGesture { emoji = em }
                    }
                }
            }
            DatePicker("Datum", selection: $date, in: Date()..., displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
            Button {
                var list = CountdownBucket.entries(config)
                list.append(.init(title: title.trimmingCharacters(in: .whitespaces), date: date, emoji: emoji))
                CountdownBucket.store(list, in: &config)
                title = ""
            } label: { Label("Countdown hinzufügen", systemImage: "plus.circle.fill") }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func remove(_ e: CountdownBucket.Entry) {
        // Einträge haben beim Lesen neue IDs → über Titel + Datum vergleichen
        let list = CountdownBucket.entries(config).filter { !($0.title == e.title && $0.date == e.date) }
        CountdownBucket.store(list, in: &config)
    }
}
