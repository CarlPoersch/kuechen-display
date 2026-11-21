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
        glance: { _, size in AnyView(TermineGlance(size: size)) },
        detail: { _ in AnyView(TermineDetail()) }
    )
}

struct CalEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let color: Color
    let location: String?

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
            .map { e in
                CalEvent(id: (e.eventIdentifier ?? UUID().uuidString) + "\(e.startDate.timeIntervalSince1970)",
                         title: e.title ?? "Termin", start: e.startDate, end: e.endDate, allDay: e.isAllDay,
                         color: Color(cgColor: e.calendar.cgColor), location: e.location)
            }
    }
}

struct TermineGlance: View {
    let size: BucketSize
    @ObservedObject private var cal = CalendarService.shared
    @Environment(\.glanceSpace) private var space

    var body: some View {
        content.refreshing(every: { 300 }) { await CalendarService.shared.start() }
    }

    /// Die nächsten Termine – heute, morgen oder später –, so viele wie in die Karte passen
    private var list: [CalEvent] {
        var out: [CalEvent] = []; var used: CGFloat = 0
        for (i, e) in cal.events.enumerated() {
            let newDay = i == 0 || Fmt.dayDiff(cal.events[i - 1].start) != Fmt.dayDiff(e.start)
            let h: CGFloat = 28 + (newDay ? 20 : 0)
            if used + h > space.height + 4 { break }
            used += h; out.append(e)
        }
        return out
    }

    @ViewBuilder private var content: some View {
        if cal.access == .denied {
            Text("Kalender-Zugriff in den Einstellungen erlauben").foregroundColor(Theme.secondary)
        } else if cal.events.isEmpty {
            Text(cal.access == .unknown ? "Lädt …" : "Keine Termine in den nächsten 60 Tagen").foregroundColor(Theme.secondary)
        } else if space.height < 90 || (space.width < 220 && size == .s), let e = cal.events.first {
            // Wenig Platz: nur der nächste Termin, groß
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.dayDiff(e.start) == 0 ? e.time : Fmt.dayLabel(e.start) + (e.allDay ? "" : " " + e.time))
                    .font(.title3.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                Text(e.title).font(.headline).lineLimit(2)
                if let l = e.location, !l.isEmpty { Text(l).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1) }
            }
        } else {
            let l = list
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
    @ObservedObject private var cal = CalendarService.shared

    private struct Day: Identifiable { let id: Date; let events: [CalEvent] }

    private var days: [Day] {
        let groups = Dictionary(grouping: cal.events) { Calendar.current.startOfDay(for: $0.start) }
        return groups.keys.sorted().map { Day(id: $0, events: groups[$0]!) }
    }

    var body: some View {
        List {
            if days.isEmpty {
                Text("Keine Termine in den nächsten 60 Tagen").foregroundColor(Theme.secondary)
            }
            ForEach(days) { day in
                Section(header: Text(Fmt.dayLabel(day.id))) {
                    ForEach(day.events) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            EventRow(event: e)
                            if !e.allDay || (e.location ?? "").isEmpty == false {
                                Text([e.allDay ? nil : "bis " + Fmt.hhmm(e.end), e.location].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.footnote).foregroundColor(Theme.secondary).padding(.leading, 98)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task { await cal.start() }
    }
}
