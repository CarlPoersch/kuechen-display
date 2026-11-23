import SwiftUI
import Combine
import EventKit

// ============================================================
// Termine-Bucket: Kalender direkt vom Gerät (EventKit).
// Warum EventKit: Alle Kalender, die in iOS angemeldet sind
// (iCloud, Google, Exchange), ohne eigenen Login. Die Termine
// verlassen das Gerät nicht.
// ============================================================
enum TermineBucket {
    static let kind = BucketKind(
        id: "termine", name: "Termine", symbol: "calendar", tint: .red, art: .glance,
        interests: ["organisation"], blurb: "Deine nächsten Termine aus dem Kalender.",
        glance: { inst, size in AnyView(TermineGlance(size: size, config: inst.config)) },
        detail: { inst in AnyView(TermineDetail(config: inst.config)) },
        settings: { binding in AnyView(TermineSettings(config: binding)) }
    )

    /// Gewählte Kalender (leer = alle)
    static func selected(_ config: [String: JSON]) -> Set<String> {
        Set((config["calendars"]?.array ?? []).compactMap(\.string))
    }

    static func filter(_ events: [CalEvent], _ config: [String: JSON]) -> [CalEvent] {
        let sel = selected(config)
        return sel.isEmpty ? events : events.filter { sel.contains($0.calendarId) }
    }
}

struct CalEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let color: Color
    let location: String?
    let calendarId: String
    let calendarName: String
    var ekId: String = ""            // zum Bearbeiten im Apple-Termin-Fenster

    var time: String { allDay ? "ganztägig" : Fmt.hhmm(start) }
}

final class CalendarService: ObservableObject {
    static let shared = CalendarService()
    enum Access { case unknown, denied, ok }

    @Published private(set) var events: [CalEvent] = []
    @Published private(set) var access: Access = .unknown
    private let store = EKEventStore()
    private var watching = false

    private var granted: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17, *) { return s == .fullAccess }
        return s == .authorized
    }

    func start() async {
        if !granted && EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            if #available(iOS 17, *) { _ = try? await store.requestFullAccessToEvents() }
            else { _ = try? await store.requestAccess(to: .event) }
        }
        access = granted ? .ok : .denied
        if !watching {
            watching = true
            // Neu laden, sobald sich im Kalender etwas ändert
            NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { @Sendable _ in
                Task { @MainActor in CalendarService.shared.reload() }
            }
        }
        reload()
    }

    func reload() {
        guard granted else { return }
        let from = Calendar.current.startOfDay(for: Date())
        let to = Calendar.current.date(byAdding: .day, value: 60, to: from)!
        let pred = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        events = store.events(matching: pred)
            .filter { $0.endDate > Date() }
            .sorted { a, b in   // je Tag: ganztägige zuerst, dann nach Uhrzeit
                let c = Calendar.current
                return (c.startOfDay(for: a.startDate), a.isAllDay ? 0 : 1, a.startDate)
                     < (c.startOfDay(for: b.startDate), b.isAllDay ? 0 : 1, b.startDate)
            }
            .map(Self.make)
        calendars = store.calendars(for: .event)
    }

    static func make(_ e: EKEvent) -> CalEvent {
        CalEvent(id: (e.eventIdentifier ?? UUID().uuidString) + "\(e.startDate.timeIntervalSince1970)",
                 title: e.title ?? "Termin", start: e.startDate, end: e.endDate, allDay: e.isAllDay,
                 color: Color(cgColor: e.calendar.cgColor), location: e.location,
                 calendarId: e.calendar.calendarIdentifier, calendarName: e.calendar.title,
                 ekId: e.eventIdentifier ?? "")
    }

    // MARK: Kalender-Ansicht und eigene Termine

    var eventStore: EKEventStore { store }

    /// Termine in einem beliebigen Zeitraum (für die Monatsansicht, auch vergangene Tage)
    func events(from: Date, to: Date) -> [CalEvent] {
        guard granted else { return [] }
        let pred = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        return store.events(matching: pred)
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map(Self.make)
    }

    func ekEvent(_ e: CalEvent) -> EKEvent? { e.ekId.isEmpty ? nil : store.event(withIdentifier: e.ekId) }

    /// Neuer Termin als Vorlage: heute zur nächsten vollen Stunde, sonst 9 Uhr, Dauer 1 Stunde
    func draft(on day: Date) -> EKEvent {
        let c = Calendar.current
        let e = EKEvent(eventStore: store)
        var start = c.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        if c.isDateInToday(day) {
            let next = c.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            start = c.date(bySetting: .minute, value: 0, of: next) ?? next
        }
        e.startDate = start
        e.endDate = c.date(byAdding: .hour, value: 1, to: start) ?? start
        e.calendar = store.defaultCalendarForNewEvents
        return e
    }

    /// Alle Kalender auf dem Gerät, nach Konto gruppiert (iCloud, Google, Abos …)
    @Published private(set) var calendars: [EKCalendar] = []

    var accounts: [(name: String, calendars: [EKCalendar])] {
        Dictionary(grouping: calendars) { $0.source?.title ?? "Andere" }
            .map { (name: $0.key, calendars: $0.value.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }) }
            .sorted { a, b in   // iCloud zuerst, Abos und Feiertage zuletzt
                func rank(_ n: String) -> Int { n == "iCloud" ? 0 : n.lowercased().contains("abonn") || n == "Other" || n == "Andere" ? 2 : 1 }
                return (rank(a.name), a.name) < (rank(b.name), b.name)
            }
    }

    /// Kalender per Abo-Link hinzufügen: iOS fragt dann selbst „Abonnieren?“
    /// und der Kalender erscheint danach in der Liste (EventKit meldet die Änderung).
    static func subscribeURL(_ raw: String) -> URL? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if t.hasPrefix("https://") { t = "webcal://" + t.dropFirst(8) }
        else if t.hasPrefix("http://") { t = "webcal://" + t.dropFirst(7) }
        else if !t.hasPrefix("webcal://") { t = "webcal://" + t }
        return URL(string: t)
    }
}

struct TermineGlance: View {
    let size: BucketSize
    let config: [String: JSON]
    @ObservedObject private var cal = CalendarService.shared
    private var events: [CalEvent] { TermineBucket.filter(cal.events, config) }
    @Environment(\.glanceSpace) private var space

    var body: some View {
        content.refreshing(every: { 300 }) { await CalendarService.shared.start() }
    }

    /// Die nächsten Termine – heute, morgen oder später –, so viele wie in die Karte passen
    private var list: [CalEvent] {
        var out: [CalEvent] = []; var used: CGFloat = 0
        let events = self.events
        for (i, e) in events.enumerated() {
            let newDay = i == 0 || Fmt.dayDiff(events[i - 1].start) != Fmt.dayDiff(e.start)
            let h: CGFloat = 28 + (newDay ? 20 : 0)
            if used + h > space.height + 4 { break }
            used += h; out.append(e)
        }
        return out
    }

    @ViewBuilder private var content: some View {
        if cal.access == .denied {
            Text("Kalender-Zugriff in den Einstellungen erlauben").foregroundColor(Theme.secondary)
        } else if events.isEmpty {
            Text(cal.access == .unknown ? "Lädt …" : "Keine Termine in den nächsten 60 Tagen").foregroundColor(Theme.secondary)
        } else if space.height < 90 || (space.width < 220 && size == .s), let e = events.first {
            // Wenig Platz: nur der nächste Termin, groß
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.dayDiff(e.start) == 0 ? e.time : Fmt.dayLabel(e.start) + (e.allDay ? "" : " " + e.time))
                    .font(.title3.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                Text(e.title).font(.headline).lineLimit(2)
                if let l = e.location, !l.isEmpty { Text(l).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1) }
            }
        } else {
            // Seiten nach Höhe füllen: Tagesüberschrift kostet extra Platz
            let pages = Pages.split(Array(events.prefix(60)), height: space.height) { e, first, prev in
                28 + ((first || prev.map { Fmt.dayDiff($0.start) != Fmt.dayDiff(e.start) } ?? true) ? 20 : 0)
            }
            GlancePager(pages: pages) { l in
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(l.enumerated()), id: \.element.id) { i, e in
                        if i == 0 || Fmt.dayDiff(l[i - 1].start) != Fmt.dayDiff(e.start) {
                            Text(Fmt.dayLabel(e.start).uppercased()).font(.caption2.weight(.semibold)).foregroundColor(Theme.secondary)
                        }
                        EventRow(event: e)
                    }
                }
            }
        }
    }
}

struct EventRow: View {
    let event: CalEvent
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 4, height: 20)
            Text(event.time).font(.subheadline.monospacedDigit()).foregroundColor(Theme.secondary)
                .frame(width: 74, alignment: .leading)
            Text(event.title).lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

struct TermineDetail: View {
    let config: [String: JSON]
    @ObservedObject private var cal = CalendarService.shared
    @State private var hidden: Set<String> = []   // hier kurz ausgeblendete Kalender
    @AppStorage("termine.ansicht") private var mode = "liste"   // pro Gerät: "liste" oder "monat"
    @State private var day = Calendar.current.startOfDay(for: Date())   // gewählter Tag in der Monatsansicht
    @State private var editor: EventEditRequest?

    private struct Day: Identifiable { let id: Date; let events: [CalEvent] }

    private var shown: [CalEvent] { TermineBucket.filter(cal.events, config).filter { !hidden.contains($0.calendarId) } }

    /// Kalender, die in dieser Karte vorkommen – als Schalter oben
    private var chips: [(id: String, name: String, color: Color)] {
        var seen = Set<String>(); var out: [(id: String, name: String, color: Color)] = []
        for e in TermineBucket.filter(cal.events, config) where !seen.contains(e.calendarId) {
            seen.insert(e.calendarId); out.append((e.calendarId, e.calendarName, e.color))
        }
        return out.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var days: [Day] {
        let groups = Dictionary(grouping: shown) { Calendar.current.startOfDay(for: $0.start) }
        return groups.keys.sorted().map { Day(id: $0, events: groups[$0]!) }
    }

    var body: some View {
        Group {
            if mode == "monat" {
                TermineMonth(config: config, hidden: hidden, day: $day) { e in
                    if let ek = cal.ekEvent(e) { editor = EventEditRequest(event: ek) }
                }
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Ansicht", selection: $mode) {
                    Text("Liste").tag("liste")
                    Text("Monat").tag("monat")
                }
                .pickerStyle(.segmented).frame(width: 190)
            }
        }
        // Neuer Termin: runder Knopf unten rechts wie in der Küche
        .overlay(alignment: .bottomTrailing) {
            if cal.access == .ok {
                Button { editor = EventEditRequest(event: cal.draft(on: mode == "monat" ? day : Date())) } label: {
                    Image(systemName: "plus").font(.system(size: 24, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Theme.accent))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                }
                .padding(20)
                .accessibilityLabel("Neuer Termin")
            }
        }
        .sheet(item: $editor) { r in
            EventEditor(event: r.event, store: cal.eventStore) { editor = nil; cal.reload() }
                .ignoresSafeArea()
        }
        .task { await cal.start() }
    }

    private var list: some View {
        List {
            if chips.count > 1 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(chips, id: \.id) { c in
                                let on = !hidden.contains(c.id)
                                Button {
                                    withAnimation { if on { hidden.insert(c.id) } else { hidden.remove(c.id) } }
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle().fill(on ? c.color : Color.clear).frame(width: 10, height: 10)
                                            .overlay(Circle().stroke(c.color, lineWidth: 1.5))
                                        Text(c.name).font(.subheadline.weight(.medium)).foregroundColor(on ? .primary : Theme.secondary)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(c.name) \(on ? "ausblenden" : "einblenden")")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            if days.isEmpty {
                Text("Keine Termine in den nächsten 60 Tagen").foregroundColor(Theme.secondary)
            }
            ForEach(days) { day in
                Section(header: Text(Fmt.dayLabel(day.id))) {
                    ForEach(day.events) { e in
                        Button { if let ek = cal.ekEvent(e) { editor = EventEditRequest(event: ek) } } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            EventRow(event: e)
                            let sub = [e.allDay ? nil : "bis " + Fmt.hhmm(e.end), e.location, chips.count > 1 ? e.calendarName : nil]
                                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                            if !sub.isEmpty {
                                Text(sub).font(.footnote).foregroundColor(Theme.secondary).padding(.leading, 98)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Color.clear.frame(height: 70).listRowBackground(Color.clear)   // Platz für den Plus-Knopf
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: Einstellungen

/// In den Bucket-Einstellungen: Name der Karte + welche Kalender
struct TermineSettings: View {
    @Binding var config: [String: JSON]
    @ObservedObject private var cal = CalendarService.shared

    private var summary: String {
        let sel = TermineBucket.selected(config).filter { id in cal.calendars.contains { $0.calendarIdentifier == id } }
        if sel.isEmpty { return "Alle" }
        if sel.count == 1, let c = cal.calendars.first(where: { sel.contains($0.calendarIdentifier) }) { return c.title }
        return "\(sel.count) Kalender"
    }

    var body: some View {
        TextField("Name der Karte, z. B. Familie", text: Binding(
            get: { config["title"]?.string ?? "" },
            set: { config["title"] = $0.isEmpty ? nil : .string($0) }))
        NavigationLink(destination: CalendarChooser(config: $config)) {
            HStack {
                Label("Kalender", systemImage: "calendar")
                Spacer()
                Text(summary).foregroundColor(Theme.secondary)
            }
        }
        .task { await cal.start() }
    }
}

/// Kalender auswählen – wie in der Kalender-App: nach Konto gruppiert, mit Farbpunkt und Haken.
/// Unten: weitere Kalender per Abo-Link hinzufügen.
struct CalendarChooser: View {
    @Binding var config: [String: JSON]
    @ObservedObject private var cal = CalendarService.shared
    @Environment(\.openURL) private var openURL
    @State private var link = ""
    @State private var showHelp = false

    private var selected: Set<String> { TermineBucket.selected(config) }
    private var allOn: Bool { selected.isEmpty }

    private func set(_ ids: Set<String>) {
        // Alle gewählt = leer speichern, dann kommen neue Kalender automatisch dazu
        let every = Set(cal.calendars.map(\.calendarIdentifier))
        config["calendars"] = ids.isEmpty || ids == every ? nil : .array(ids.sorted().map { .string($0) })
    }

    private func isOn(_ c: EKCalendar) -> Bool { allOn || selected.contains(c.calendarIdentifier) }

    private func toggle(_ c: EKCalendar) {
        var ids = allOn ? Set(cal.calendars.map(\.calendarIdentifier)) : selected
        if ids.contains(c.calendarIdentifier) {
            guard ids.count > 1 else { return }   // mindestens einer bleibt
            ids.remove(c.calendarIdentifier)
        } else { ids.insert(c.calendarIdentifier) }
        withAnimation { set(ids) }
    }

    var body: some View {
        List {
            if cal.access == .denied {
                Section {
                    Text("Hubert darf noch nicht auf deine Kalender zugreifen.")
                    Button("In den Einstellungen erlauben") {
                        if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) }
                    }
                }
            }
            ForEach(cal.accounts, id: \.name) { acc in
                Section(acc.name) {
                    ForEach(acc.calendars, id: \.calendarIdentifier) { c in
                        Button { toggle(c) } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color(cgColor: c.cgColor)).frame(width: 14, height: 14)
                                Text(c.title).foregroundColor(.primary)
                                Spacer()
                                if isOn(c) { Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundColor(Theme.accent) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(c.title + (isOn(c) ? ", angezeigt" : ", ausgeblendet"))
                    }
                }
            }

            Section {
                HStack {
                    Image(systemName: "link").foregroundColor(Theme.secondary)
                    TextField("Abo-Link (webcal:// oder https://…ics)", text: $link)
                        .keyboardType(.URL).textInputAutocapitalization(.never).disableAutocorrection(true)
                        .submitLabel(.go).onSubmit(subscribe)
                }
                Button(action: subscribe) { Label("Kalender abonnieren", systemImage: "plus.circle.fill") }
                    .disabled(CalendarService.subscribeURL(link) == nil)
                Button { showHelp.toggle() } label: {
                    Label("Kalender von jemand anderem anzeigen", systemImage: showHelp ? "chevron.down" : "person.2")
                }
                if showHelp {
                    VStack(alignment: .leading, spacing: 8) {
                        helpRow("1", "iCloud: In der Kalender-App auf ihrem iPhone den Kalender antippen → ⓘ → „Person hinzufügen“ → deine Apple-ID.")
                        helpRow("2", "Du nimmst die Einladung an – der Kalender erscheint hier automatisch.")
                        helpRow("3", "Google oder Outlook: Konto unter Einstellungen → Kalender → Accounts hinzufügen, oder den „geheimen iCal-Link“ oben als Abo einfügen.")
                    }
                    .font(.footnote).padding(.vertical, 4)
                }
            } header: { Text("Weitere Kalender") } footer: {
                Text("Abos wie Müllabfuhr, Ferien, Feiertage oder Spielpläne fragt iOS kurz ab und zeigt sie dann hier. Termine bleiben auf dem Gerät.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !allOn { Button("Alle anzeigen") { withAnimation { set([]) } } }
            }
        }
        .task { await cal.start() }
    }

    private func subscribe() {
        guard let u = CalendarService.subscribeURL(link) else { return }
        openURL(u)
        link = ""
    }

    private func helpRow(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n).font(.caption.weight(.bold)).foregroundColor(.white)
                .frame(width: 20, height: 20).background(Circle().fill(Theme.accent))
            Text(text).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
