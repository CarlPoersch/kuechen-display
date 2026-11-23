import SwiftUI
import EventKit
import EventKitUI

// ============================================================
// Termine: Monatsansicht und Termine anlegen/bearbeiten.
// Anlegen und Bearbeiten laufen über das Apple-Termin-Fenster
// (EKEventEditViewController) – mit Wiederholung, Erinnerung,
// Ort und Kalenderwahl, ohne dass Hubert das nachbauen muss.
// ============================================================

struct EventEditRequest: Identifiable {
    let id = UUID()
    let event: EKEvent
}

/// Apples Fenster „Neues Ereignis“ / „Ereignis bearbeiten“
struct EventEditor: UIViewControllerRepresentable {
    let event: EKEvent
    let store: EKEventStore
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let vc = EKEventEditViewController()
        vc.eventStore = store
        vc.event = event
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}

/// Kalender wie in Apples Kalender-App: Monate untereinander, senkrecht scrollen.
/// Zoom (zwei Finger oder Lupen-Knöpfe): 0 = Punkte, 1 = Titel, 2 = Titel mit Uhrzeit.
struct TermineMonth: View {
    let config: [String: JSON]
    let hidden: Set<String>
    @Binding var day: Date
    @ObservedObject private var cal = CalendarService.shared
    @AppStorage("termine.zoom") private var zoom = 1
    @State private var showDay = false

    static var c: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "de_DE"); c.firstWeekday = 2; c.timeZone = .current
        return c
    }
    static func monthStart(_ d: Date) -> Date { c.date(from: c.dateComponents([.year, .month], from: d))! }

    /// 3 Monate zurück bis 12 Monate voraus
    private var months: [Date] {
        let now = Self.monthStart(Date())
        return (-3...12).compactMap { Self.c.date(byAdding: .month, value: $0, to: now) }
    }

    private func setZoom(_ z: Int) { withAnimation(.easeOut(duration: 0.2)) { zoom = max(0, min(2, z)) } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                    ForEach(months, id: \.self) { m in
                        Section {
                            MonthGrid(month: m, config: config, hidden: hidden, zoom: zoom, selected: day) { d in
                                day = d; showDay = true
                            }
                        } header: {
                            Text(Self.title(m)).font(.title3.weight(.bold))
                                .foregroundColor(Self.c.isDate(m, equalTo: Date(), toGranularity: .month) ? Theme.accent : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(Theme.background)
                                .id(m)
                        }
                    }
                }
                .padding(.bottom, 100)       // Platz für den Plus-Knopf
            }
            .onAppear {
                let now = Self.monthStart(Date())
                DispatchQueue.main.async { proxy.scrollTo(now, anchor: .top) }
            }
            .safeAreaInset(edge: .top, spacing: 0) { topBar(proxy) }
        }
        .background(Theme.background)
        // Zwei Finger auseinander = mehr Text, zusammen = kompakter
        .simultaneousGesture(MagnificationGesture().onEnded { s in
            if s > 1.15 { setZoom(zoom + 1) } else if s < 0.87 { setZoom(zoom - 1) }
        })
        .sheet(isPresented: $showDay) { DaySheet(day: day, config: config, hidden: hidden) }
    }

    /// Wochentage + Heute + Lupen, bleibt beim Scrollen oben stehen
    private func topBar(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Button("Heute") {
                    withAnimation { proxy.scrollTo(Self.monthStart(Date()), anchor: .top) }
                    day = Self.c.startOfDay(for: Date())
                }
                .font(.subheadline.weight(.semibold)).foregroundColor(Theme.accent)
                Spacer()
                Button { setZoom(zoom - 1) } label: {
                    Image(systemName: "minus.magnifyingglass").frame(width: 44, height: 36)
                }
                .disabled(zoom == 0).accessibilityLabel("Weniger Details")
                Button { setZoom(zoom + 1) } label: {
                    Image(systemName: "plus.magnifyingglass").frame(width: 44, height: 36)
                }
                .disabled(zoom == 2).accessibilityLabel("Mehr Details")
            }
            .foregroundColor(Theme.accent)
            HStack(spacing: 0) {
                ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { s in
                    Text(s).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 6)
        .background(Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Divider() }
    }

    static func title(_ m: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE")
        f.dateFormat = c.isDate(m, equalTo: Date(), toGranularity: .year) ? "LLLL" : "LLLL yyyy"
        return f.string(from: m)
    }
}

/// Ein Monat als Raster. Lädt seine Termine selbst (nur sichtbare Monate fragen den Kalender ab).
private struct MonthGrid: View {
    let month: Date
    let config: [String: JSON]
    let hidden: Set<String>
    let zoom: Int
    let selected: Date
    let onTap: (Date) -> Void
    @ObservedObject private var cal = CalendarService.shared

    private var c: Calendar { TermineMonth.c }

    private var cellHeight: CGFloat { [50, 92, 128][zoom] }
    private var maxTitles: Int { [0, 3, 4][zoom] }

    var body: some View {
        let end = c.date(byAdding: .month, value: 1, to: month)!
        let all = TermineBucket.filter(cal.events(from: month, to: end), config).filter { !hidden.contains($0.calendarId) }
        // Mehrtägige Termine an jedem Tag zeigen, den sie berühren
        let byDay: [Date: [CalEvent]] = {
            var d: [Date: [CalEvent]] = [:]
            for e in all {
                var t = c.startOfDay(for: max(e.start, month))
                let last = e.end > e.start ? e.end.addingTimeInterval(-1) : e.start
                while t <= last && t < end {
                    d[t, default: []].append(e)
                    t = c.date(byAdding: .day, value: 1, to: t)!
                }
            }
            return d
        }()
        let count = c.range(of: .day, in: .month, for: month)?.count ?? 30
        let lead = (c.component(.weekday, from: month) - c.firstWeekday + 7) % 7
        let cells: [Date?] = Array(repeating: nil, count: lead) + (0..<count).map { c.date(byAdding: .day, value: $0, to: month) }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                if let d = d {
                    cell(d, events: byDay[d] ?? [])
                } else {
                    Color.clear.frame(height: cellHeight)
                }
            }
        }
        .padding(.horizontal, zoom == 0 ? 12 : 4)
    }

    private func cell(_ d: Date, events: [CalEvent]) -> some View {
        let isSel = c.isDate(d, inSameDayAs: selected)
        let isToday = c.isDateInToday(d)
        let weekend = c.isDateInWeekend(d)
        return Button { onTap(d) } label: {
            VStack(alignment: zoom == 0 ? .center : .leading, spacing: 2) {
                Text("\(c.component(.day, from: d))")
                    .font(.system(size: zoom == 0 ? 17 : 14, weight: isToday || isSel ? .semibold : .regular)).monospacedDigit()
                    .foregroundColor(isToday ? .white : isSel ? Theme.accent : weekend ? Theme.secondary : .primary)
                    .frame(width: zoom == 0 ? 34 : 24, height: zoom == 0 ? 34 : 24)
                    .background(Circle().fill(isToday ? Theme.accent : isSel ? Theme.accent.opacity(0.15) : Color.clear))
                    .frame(maxWidth: .infinity, alignment: zoom == 0 ? .center : .leading)
                if zoom == 0 {
                    dots(events)
                } else {
                    ForEach(events.prefix(maxTitles)) { e in chip(e) }
                    if events.count > maxTitles {
                        Text("+\(events.count - maxTitles)").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, zoom == 0 ? 0 : 2).padding(.top, 3)
            .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight, alignment: .top)
            .overlay(alignment: .top) { if zoom > 0 { Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Fmt.dayLabel(d) + (events.isEmpty ? "" : ", \(events.count) Termine"))
    }

    /// bis zu drei Punkte, je Kalenderfarbe einer
    private func dots(_ events: [CalEvent]) -> some View {
        var colors: [Color] = []
        var seen = Set<String>()
        for e in events where !seen.contains(e.calendarId) && colors.count < 3 { seen.insert(e.calendarId); colors.append(e.color) }
        return HStack(spacing: 3) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, col in Circle().fill(col).frame(width: 5, height: 5) }
        }
        .frame(maxWidth: .infinity).frame(height: 5)
    }

    /// Termin als farbiges Kärtchen mit Titel (Zoom 2: mit Uhrzeit)
    private func chip(_ e: CalEvent) -> some View {
        let text = (zoom == 2 && !e.allDay ? Fmt.hhmm(e.start) + " " : "") + e.title
        return HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 1).fill(e.color).frame(width: 2.5)
            Text(text).font(.system(size: zoom == 2 ? 11 : 10, weight: .medium)).lineLimit(1).foregroundColor(.primary)
            Spacer(minLength: 0)
        }
        .frame(height: zoom == 2 ? 16 : 14)
        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(e.color.opacity(e.allDay ? 0.25 : 0.12)))
    }
}

/// Tagesansicht nach Tipp auf einen Tag: Termine ansehen, bearbeiten, neu anlegen
private struct DaySheet: View {
    let day: Date
    let config: [String: JSON]
    let hidden: Set<String>
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cal = CalendarService.shared
    @State private var editor: EventEditRequest?

    var body: some View {
        let c = TermineMonth.c
        let start = c.startOfDay(for: day), end = c.date(byAdding: .day, value: 1, to: start)!
        let events = TermineBucket.filter(cal.events(from: start, to: end), config).filter { !hidden.contains($0.calendarId) }
        NavigationView {
            List {
                if events.isEmpty {
                    Text("Keine Termine").foregroundColor(Theme.secondary)
                }
                ForEach(events) { e in
                    Button { if let ek = cal.ekEvent(e) { editor = EventEditRequest(event: ek) } } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            EventRow(event: e)
                            let sub = [e.allDay ? nil : "bis " + Fmt.hhmm(e.end), e.location, e.calendarName]
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
            .listStyle(.insetGrouped)
            .navigationTitle(Fmt.dayLabel(day)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { editor = EventEditRequest(event: cal.draft(on: day)) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Neuer Termin an diesem Tag")
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(item: $editor) { r in
            EventEditor(event: r.event, store: cal.eventStore) { editor = nil; cal.reload() }
                .ignoresSafeArea()
        }
    }
}
