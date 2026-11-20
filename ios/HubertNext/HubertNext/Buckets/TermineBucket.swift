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
        interests: ["organisation"], blurb: "Heute und morgen aus deinem Kalender.",
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
            NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
                Task { @MainActor in CalendarService.shared.reload() }
            }
        }
        reload()
    }

    func reload() {
        guard granted else { return }
        let from = Calendar.current.startOfDay(for: Date())
        let to = Calendar.current.date(byAdding: .day, value: 7, to: from)!
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

    var body: some View {
        content.refreshing(every: { 300 }) { await CalendarService.shared.start() }
    }

    @ViewBuilder private var content: some View {
        // Startseite: nur heute und morgen
        let soon = cal.events.filter { Fmt.dayDiff($0.start) <= 1 }
        if cal.access == .denied {
            Text("Kalender-Zugriff in den Einstellungen erlauben").foregroundColor(Theme.secondary)
        } else if soon.isEmpty {
            Text(cal.access == .unknown ? "Lädt …" : "Heute und morgen frei").foregroundColor(Theme.secondary)
        } else if size == .s, let e = soon.first {
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.dayDiff(e.start) == 0 ? e.time : "Morgen " + e.time)
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(e.title).font(.headline).lineLimit(2)
                if let l = e.location, !l.isEmpty { Text(l).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(1) }
            }
        } else {
            let list = Array(soon.prefix(size == .m ? 3 : 6))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                    if i == 0 || Fmt.dayDiff(list[i - 1].start) != Fmt.dayDiff(e.start) {
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
                Text("Die nächsten 7 Tage sind frei").foregroundColor(Theme.secondary)
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
