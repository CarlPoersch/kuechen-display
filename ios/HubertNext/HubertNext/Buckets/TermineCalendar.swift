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

/// Monatsraster (Montag zuerst) mit farbigen Punkten, darunter die Termine des gewählten Tags
struct TermineMonth: View {
    let config: [String: JSON]
    let hidden: Set<String>
    @Binding var day: Date
    let onOpen: (CalEvent) -> Void
    @ObservedObject private var cal = CalendarService.shared
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!

    private var c: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "de_DE"); c.firstWeekday = 2; c.timeZone = .current
        return c
    }

    /// Alle Kästchen des Monats: führende Leerfelder (nil), dann die Tage
    private var cells: [Date?] {
        let first = month
        let count = c.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = (c.component(.weekday, from: first) - c.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + (0..<count).map { c.date(byAdding: .day, value: $0, to: first) }
    }

    private var title: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "LLLL yyyy"
        return f.string(from: month)
    }

    private func shift(_ n: Int) {
        guard let m = c.date(byAdding: .month, value: n, to: month) else { return }
        month = m
        // Gewählten Tag mitnehmen: heute, falls im Monat, sonst der 1.
        day = c.isDate(Date(), equalTo: m, toGranularity: .month) ? c.startOfDay(for: Date()) : m
    }

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
        let selected = byDay[c.startOfDay(for: day)] ?? []
        let symbols = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

        List {
            Section {
                VStack(spacing: 10) {
                    HStack {
                        Button { withAnimation(.easeOut(duration: 0.2)) { shift(-1) } } label: {
                            Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless).accessibilityLabel("Vorheriger Monat")
                        Spacer()
                        Text(title).font(.headline)
                        Spacer()
                        Button { withAnimation(.easeOut(duration: 0.2)) { shift(1) } } label: {
                            Image(systemName: "chevron.right").font(.body.weight(.semibold)).frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless).accessibilityLabel("Nächster Monat")
                    }
                    .foregroundColor(Theme.accent)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                        ForEach(symbols, id: \.self) { s in
                            Text(s).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                        }
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                            if let d = d {
                                cell(d, events: byDay[d] ?? [])
                            } else {
                                Color.clear.frame(height: 48)
                            }
                        }
                    }

                    if !c.isDate(Date(), equalTo: month, toGranularity: .month) {
                        Button("Heute") {
                            withAnimation(.easeOut(duration: 0.2)) {
                                month = c.date(from: c.dateComponents([.year, .month], from: Date()))!
                                day = c.startOfDay(for: Date())
                            }
                        }
                        .buttonStyle(.borderless).font(.subheadline.weight(.semibold)).foregroundColor(Theme.accent)
                    }
                }
                .padding(.vertical, 6)
            }

            Section(header: Text(Fmt.dayLabel(day))) {
                if selected.isEmpty {
                    Text("Keine Termine").foregroundColor(Theme.secondary)
                }
                ForEach(selected) { e in
                    Button { onOpen(e) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            EventRow(event: e)
                            let sub = [e.allDay ? nil : "bis " + Fmt.hhmm(e.end), e.location]
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
            Color.clear.frame(height: 70).listRowBackground(Color.clear)   // Platz für den Plus-Knopf
        }
        .listStyle(.insetGrouped)
    }

    private func cell(_ d: Date, events: [CalEvent]) -> some View {
        let isSel = c.isDate(d, inSameDayAs: day)
        let isToday = c.isDateInToday(d)
        // bis zu drei Punkte, je Kalenderfarbe einer
        var colors: [Color] = []
        var seen = Set<String>()
        for e in events where !seen.contains(e.calendarId) && colors.count < 3 { seen.insert(e.calendarId); colors.append(e.color) }
        return Button { withAnimation(.easeOut(duration: 0.15)) { day = d } } label: {
            VStack(spacing: 4) {
                Text("\(c.component(.day, from: d))")
                    .font(.body.weight(isToday || isSel ? .semibold : .regular)).monospacedDigit()
                    .foregroundColor(isSel ? .white : isToday ? Theme.accent : .primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isSel ? Theme.accent : Color.clear))
                HStack(spacing: 3) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, col in
                        Circle().fill(col).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Fmt.dayLabel(d) + (events.isEmpty ? "" : ", \(events.count) Termine"))
    }
}
