import SwiftUI

// ============================================================
// Countdowns – App und Sammelstelle: „Noch 42 Tage bis Wien“.
// Arten: Termin, Prüfung/Lernziel (später mit Fokus-Minuten), Reise (mit Enddatum).
// Einstellungen: entries = [{ id, title, date (yyyy-MM-dd), emoji, type, end? }]
// ============================================================
enum CountdownBucket {
    static let kind = BucketKind(
        id: "countdown", name: "Countdowns", symbol: "hourglass", tint: .purple, art: .glance,
        interests: ["organisation", "unterwegs", "freizeit"], blurb: "Tage bis zur Reise, Prüfung oder zum Geburtstag – alles an einem Ort.",
        needsSetup: { ($0["entries"]?.array ?? []).isEmpty },
        glance: { inst, size in AnyView(CountdownGlance(config: inst.config, size: size)) },
        detail: { inst in AnyView(CountdownApp(bucketId: inst.id)) },
        settings: { binding in AnyView(CountdownEditor(config: binding)) }
    )

    /// Art eines Countdowns
    enum Kind: String, CaseIterable, Identifiable {
        case termin, pruefung, reise
        var id: String { rawValue }
        var label: String { self == .termin ? "Termin" : self == .pruefung ? "Prüfung" : "Reise" }
        var section: String { self == .termin ? "Termine" : self == .pruefung ? "Prüfungen & Lernziele" : "Reisen" }
        var symbol: String { self == .termin ? "calendar" : self == .pruefung ? "graduationcap.fill" : "airplane" }
        var emojis: [String] {
            switch self {
            case .termin: return ["🎂", "🎉", "🎄", "❤️", "⚽️", "🎾", "🎓", "⏳"]
            case .pruefung: return ["📚", "🎓", "⚖️", "📝", "💼", "🧠", "📊", "⏳"]
            case .reise: return ["✈️", "🏖️", "🏔️", "🚆", "🚗", "🗺️", "🎡", "⛷️"]
            }
        }
    }

    struct Entry: Identifiable, Equatable {
        var id = UUID().uuidString.lowercased()   // bleibt gleich (später: Fokus-Minuten hängen daran)
        var title: String
        var date: Date
        var emoji: String
        var type: Kind = .termin
        var end: Date? = nil                      // Reise: letzter Tag

        /// Noch nicht vorbei (bei Reisen: bis zum letzten Tag)
        var upcoming: Bool { CountdownBucket.daysLeft(end ?? date) >= 0 }
        /// Reise läuft gerade
        var running: Bool { type == .reise && CountdownBucket.daysLeft(date) < 0 && (end.map { CountdownBucket.daysLeft($0) >= 0 } ?? false) }
    }

    static let dayFormat: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    static func entries(_ config: [String: JSON]) -> [Entry] {
        (config["entries"]?.array ?? []).compactMap { j in
            guard let o = j.object, let t = o["title"]?.string, let ds = o["date"]?.string,
                  let d = dayFormat.date(from: ds) else { return nil }
            // Alte Einträge ohne id: aus Titel + Datum ableiten, damit sie stabil bleibt
            return Entry(id: o["id"]?.string ?? (t + "|" + ds), title: t, date: d, emoji: o["emoji"]?.string ?? "⏳",
                         type: Kind(rawValue: o["type"]?.string ?? "") ?? .termin,
                         end: o["end"]?.string.flatMap { dayFormat.date(from: $0) })
        }
    }

    static func store(_ list: [Entry], in config: inout [String: JSON]) {
        config["entries"] = .array(list.map { e in
            var o: [String: JSON] = ["id": .string(e.id), "title": .string(e.title), "date": .string(dayFormat.string(from: e.date)),
                                     "emoji": .string(e.emoji), "type": .string(e.type.rawValue)]
            if let end = e.end, e.type == .reise { o["end"] = .string(dayFormat.string(from: end)) }
            return JSON.object(o)
        })
    }

    /// „40 Tage“, „Morgen“, „Unterwegs“
    static func label(_ e: Entry) -> String {
        if e.running { return "Unterwegs" }
        let d = daysLeft(e.date)
        return d == 0 ? "Heute" : d == 1 ? "Morgen" : "\(d) Tage"
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
            .filter { $0.upcoming }
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
                Text(CountdownBucket.label(e)).font(.system(size: big, weight: .semibold).monospacedDigit())
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
                        Text(CountdownBucket.label(e))
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

    private var valid: Bool { !entry.title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var endBinding: Binding<Date> {
        Binding(get: { max(entry.end ?? entry.date, entry.date) }, set: { entry.end = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Art", selection: $entry.type) {
                ForEach(CountdownBucket.Kind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: entry.type) { t in
                // Passendes Symbol vorschlagen; Reisen bekommen ein Enddatum
                if !t.emojis.contains(entry.emoji) { entry.emoji = t.emojis[0] }
                if t == .reise && entry.end == nil { entry.end = Calendar.current.date(byAdding: .day, value: 3, to: entry.date) }
            }
            TextField(entry.type == .pruefung ? "Welche Prüfung? z. B. Klausur Recht" : entry.type == .reise ? "Wohin? z. B. Wien" : "Wofür? z. B. Geburtstag Mama",
                      text: $entry.title).textFieldStyle(.roundedBorder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(entry.type.emojis, id: \.self) { em in
                        Text(em).font(.title2).padding(6)
                            .background(Circle().fill(em == entry.emoji ? Theme.accent.opacity(0.2) : Color.clear))
                            .onTapGesture { entry.emoji = em }
                    }
                }
            }
            DatePicker(entry.type == .reise ? "Ab" : "Datum", selection: $entry.date,
                       in: min(Calendar.current.startOfDay(for: Date()), entry.date)..., displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
            if entry.type == .reise {
                DatePicker("Bis", selection: endBinding, in: entry.date..., displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
            }
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

// MARK: App

/// Countdowns als App: Sammelstelle für Prüfungen, Reisen und Termine
struct CountdownApp: View {
    let bucketId: String
    @EnvironmentObject var store: AppStore
    @ObservedObject private var focus = FocusCenter.shared
    @State private var sheet: Sheet?
    @State private var showPast = false

    /// Blatt: neuer Eintrag (mit Art) oder Bearbeiten (mit id)
    private struct Sheet: Identifiable { let id: String; let entry: CountdownBucket.Entry; let isNew: Bool }

    private var config: [String: JSON] { store.buckets.first { $0.id == bucketId }?.config ?? [:] }

    var body: some View {
        let all = CountdownBucket.entries(config)
        let coming = all.filter { $0.upcoming }.sorted { $0.date < $1.date }
        let past = all.filter { !$0.upcoming }.sorted { $0.date > $1.date }
        List {
            if all.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch keine Countdowns").font(.headline)
                        Text("Leg Prüfungen, Reisen oder Termine an – Hubert zählt die Tage runter.")
                            .font(.subheadline).foregroundColor(Theme.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            // Nächster groß oben
            if let next = coming.first {
                Section {
                    Button { edit(next) } label: { hero(next) }.buttonStyle(.plain)
                }
            }
            ForEach([CountdownBucket.Kind.pruefung, .reise, .termin]) { k in
                let list = coming.filter { $0.type == k }
                if !list.isEmpty {
                    Section(k.section) {
                        ForEach(list) { e in
                            Button { edit(e) } label: { row(e) }.buttonStyle(.plain)
                        }
                        .onDelete { idx in remove(idx.map { list[$0].id }) }
                    }
                }
            }
            Section {
                ForEach(CountdownBucket.Kind.allCases) { k in
                    Button { add(k) } label: { Label(k.label + " hinzufügen", systemImage: k.symbol) }
                }
            }
            if !past.isEmpty {
                Section {
                    if showPast {
                        ForEach(past) { e in
                            Button { edit(e) } label: { row(e).opacity(0.55) }.buttonStyle(.plain)
                        }
                        .onDelete { idx in remove(idx.map { past[$0].id }) }
                    }
                } header: {
                    Button { withAnimation { showPast.toggle() } } label: {
                        HStack {
                            Text("Vorbei (\(past.count))")
                            Image(systemName: showPast ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(CountdownBucket.Kind.allCases) { k in
                        Button { add(k) } label: { Label(k.label, systemImage: k.symbol) }
                    }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("Countdown hinzufügen")
            }
        }
        .sheet(item: $sheet) { sh in
            CountdownEditSheet(entry: sh.entry, isNew: sh.isNew,
                               onSave: { save($0) },
                               onDelete: sh.isNew ? nil : { remove([sh.entry.id]) })
        }
    }

    // MARK: Zeilen

    private func dateLine(_ e: CountdownBucket.Entry) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EE, d. MMM yyyy"
        var s = f.string(from: e.date)
        if e.type == .reise, let end = e.end, end > e.date {
            let n = (Calendar.current.dateComponents([.day], from: e.date, to: end).day ?? 0) + 1
            s += " – " + f.string(from: end) + " · \(n) Tage"
        }
        return s
    }

    private func hero(_ e: CountdownBucket.Entry) -> some View {
        HStack(spacing: 16) {
            Text(e.emoji).font(.system(size: 54))
            VStack(alignment: .leading, spacing: 4) {
                Text(e.type.label.uppercased()).font(.caption.weight(.semibold)).foregroundColor(Theme.accent)
                Text(e.title).font(.title3.weight(.semibold)).lineLimit(2)
                Text(dateLine(e)).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                if e.running || CountdownBucket.daysLeft(e.date) <= 1 {
                    Text(CountdownBucket.label(e)).font(.title2.weight(.bold)).foregroundColor(Theme.accent)
                } else {
                    Text("\(CountdownBucket.daysLeft(e.date))").font(.system(size: 40, weight: .bold).monospacedDigit())
                    Text("Tage").font(.caption).foregroundColor(Theme.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func row(_ e: CountdownBucket.Entry) -> some View {
        let d = CountdownBucket.daysLeft(e.date)
        return HStack(spacing: 12) {
            Text(e.emoji).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.body.weight(.semibold)).foregroundColor(.primary).lineLimit(1)
                Text(dateLine(e)).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                // Lernzeit aus dem Fokus-Timer
                let m = focus.state.minutes(countdown: e.id)
                if m > 0 { Label(hours(m) + " fokussiert", systemImage: "brain.head.profile").font(.caption.weight(.semibold)).foregroundColor(Theme.accent) }
            }
            Spacer(minLength: 6)
            Text(e.upcoming ? CountdownBucket.label(e) : "vorbei")
                .font(.headline.monospacedDigit())
                .foregroundColor(e.upcoming && (e.running || d <= 7) ? Theme.accent : .primary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: Ändern

    private func add(_ k: CountdownBucket.Kind) {
        var e = CountdownBucket.Entry(title: "", date: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
                                      emoji: k.emojis[0], type: k)
        if k == .reise { e.end = Calendar.current.date(byAdding: .day, value: 33, to: Date()) }
        sheet = Sheet(id: e.id, entry: e, isNew: true)
    }
    private func edit(_ e: CountdownBucket.Entry) { sheet = Sheet(id: e.id, entry: e, isNew: false) }

    private func save(_ e: CountdownBucket.Entry) {
        store.updateConfig(bucketId) { c in
            var l = CountdownBucket.entries(c)
            if let i = l.firstIndex(where: { $0.id == e.id }) { l[i] = e } else { l.append(e) }
            CountdownBucket.store(l, in: &c)
        }
    }
    private func remove(_ ids: [String]) {
        store.updateConfig(bucketId) { c in
            var l = CountdownBucket.entries(c)
            l.removeAll { ids.contains($0.id) }
            CountdownBucket.store(l, in: &c)
        }
    }
}

/// Blatt zum Anlegen/Bearbeiten eines Countdowns
struct CountdownEditSheet: View {
    let entry: CountdownBucket.Entry
    let isNew: Bool
    let onSave: (CountdownBucket.Entry) -> Void
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let del: (() -> Void)? = onDelete == nil ? nil : { onDelete?(); dismiss() }
        NavigationView {
            Form {
                Section {
                    CountdownForm(entry: entry, saveTitle: isNew ? "Hinzufügen" : "Sichern",
                                  onSave: { onSave($0); dismiss() },
                                  onCancel: { dismiss() },
                                  onDelete: del)
                        .padding(.vertical, 6)
                }
            }
            .navigationTitle(isNew ? "Neuer Countdown" : "Countdown")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}
