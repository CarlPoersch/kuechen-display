import SwiftUI

// ============================================================
// „Inseln“ unten – wie die Dynamic Island:
// Läuft ein Rezept im Hintergrund und/oder ein Timer, schwebt unten
// je eine schwarze Kapsel. Läuft beides, stehen sie nebeneinander;
// laufen mehrere Timer, kommt ein kleiner runder Ableger dazu.
//  · Antippen: Kochmodus fortsetzen bzw. laufende Timer öffnen
//  · Lange drücken: Schnellaktionen (Kochen beenden, Timer pausieren/stoppen)
// ============================================================

struct ActivityBar: View {
    @ObservedObject private var session = CookSession.shared
    @ObservedObject private var center = TimerCenter.shared
    @State private var showTimers = false
    @State private var cookActions = false
    @State private var confirmCancel = false
    @State private var timerActions = false

    private var cooking: Recipe? { session.presented ? nil : session.recipe }
    private var sorted: [KitchenTimer] { center.timers.sorted { $0.left < $1.left } }

    var body: some View {
        HStack(spacing: 8) {
            if let r = cooking { cookIsland(r, compact: !center.timers.isEmpty) }
            if let t = sorted.first {
                timerIsland(t)
                if sorted.count > 1 { extraIsland(sorted[1], more: sorted.count - 1) }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cooking?.id)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: center.timers.count)
        .sheet(isPresented: $showTimers) { RunningTimersSheet() }
    }

    // MARK: Kochen

    private func cookIsland(_ r: Recipe, compact: Bool) -> some View {
        let total = max(1, r.steps.count)
        let done = Double(min(session.page, total)) / Double(total)
        return HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 3)
                Circle().trim(from: 0, to: max(0.02, done)).stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(r.icon).font(.system(size: 15))
            }
            .frame(width: 30, height: 30)
            if compact {
                Text(session.page < r.steps.count ? "\(session.page + 1)/\(r.steps.count)" : "Fertig")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(r.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(session.stepText).font(.caption).foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: 190, alignment: .leading)
            }
        }
        .island()
        .onTapGesture { session.resume() }
        .onLongPressGesture { cookActions = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(r.title) kochen, \(session.stepText)")
        .accessibilityHint("Tippen zum Weiterkochen, lange drücken zum Abbrechen")
        .accessibilityAddTraits(.isButton)
        .confirmationDialog(r.title, isPresented: $cookActions, titleVisibility: .visible) {
            Button("Weiterkochen") { session.resume() }
            Button("Kochen abbrechen …", role: .destructive) { afterMenu { confirmCancel = true } }
            Button("Schließen", role: .cancel) {}
        }
        .cancelCookingAlert($confirmCancel)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    // MARK: Timer

    private func timerIsland(_ t: KitchenTimer) -> some View {
        HStack(spacing: 10) {
            ZStack {
                TimerRing(timer: t, line: 3, color: .orange)
                if let i = t.icon { Text(i).font(.system(size: 13)) }
            }
            .frame(width: 26, height: 26)
            Text(TimerCenter.format(t.left))
                .font(.headline.monospacedDigit())
                .foregroundColor(t.pausedLeft != nil ? .white.opacity(0.5) : t.left < 60 ? .orange : .white)
            if cooking == nil && sorted.count == 1 {
                Text(t.name).font(.subheadline).foregroundColor(.white.opacity(0.6)).lineLimit(1).frame(maxWidth: 150)
            }
        }
        .island()
        .onTapGesture { showTimers = true }
        .onLongPressGesture { timerActions = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Timer \(t.name), noch \(TimerCenter.format(t.left))")
        .accessibilityHint("Tippen öffnet alle Timer, lange drücken für Pause und Stopp")
        .accessibilityAddTraits(.isButton)
        .confirmationDialog(t.name, isPresented: $timerActions, titleVisibility: .visible) {
            Button(t.pausedLeft == nil ? "Pausieren" : "Fortsetzen") { center.pause(t) }
            Button("+1 Minute") { center.add(t, minutes: 1) }
            Button("Timer stoppen", role: .destructive) { center.cancel(t) }
            Button("Abbrechen", role: .cancel) {}
        }
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    /// Kleiner runder Ableger für weitere Timer
    private func extraIsland(_ t: KitchenTimer, more: Int) -> some View {
        ZStack {
            TimerRing(timer: t, line: 3, color: .orange).frame(width: 26, height: 26)
            Text(more == 1 ? (t.icon ?? "2") : "+\(more)").font(.system(size: more == 1 && t.icon != nil ? 13 : 12, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 46, height: 46)
        .background(Circle().fill(Color.black))
        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .onTapGesture { showTimers = true }
        .accessibilityLabel(more == 1 ? "Zweiter Timer \(t.name)" : "\(more) weitere Timer")
        .accessibilityAddTraits(.isButton)
        .transition(.scale(scale: 0.3).combined(with: .opacity))
    }
}

private extension View {
    /// Schwarze Kapsel im Stil der Dynamic Island
    func island() -> some View {
        self.foregroundColor(.white)
            .padding(.leading, 9).padding(.trailing, 16).frame(height: 46)
            .background(Capsule().fill(Color.black))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))   // im Dunkelmodus sichtbar
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            .contentShape(Capsule())
    }
}

/// Alle laufenden Timer (aus der Insel unten): bearbeiten, pausieren, stoppen, neuen starten
struct RunningTimersSheet: View {
    @ObservedObject private var center = TimerCenter.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editing: KitchenTimer?

    var body: some View {
        NavigationView {
            List {
                if center.timers.isEmpty { Text("Kein Timer läuft").foregroundColor(Theme.secondary) }
                Section {
                    ForEach(center.timers.sorted { $0.left < $1.left }) { t in
                        TimerCard(timer: t) { editing = t }
                    }
                }
                Section {
                    NavigationLink(destination: TimerToolView().navigationTitle("Timer").navigationBarTitleDisplayMode(.inline)) {
                        Label("Neuer Timer", systemImage: "plus.circle.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timer").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sheet(item: $editing) { TimerEditSheet(timer: $0) }
        }
        .navigationViewStyle(.stack)
    }
}
