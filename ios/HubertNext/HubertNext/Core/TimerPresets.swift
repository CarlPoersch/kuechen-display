import SwiftUI
import Combine

// ============================================================
// Timer-Vorlagen des Haushalts (Tabelle timer_presets): ein Tipp startet den Timer.
// Mitgeliefert (feste IDs, damit zwei Geräte sie nicht doppelt anlegen):
// Eier 8 Min., Tee 4 Min., Pizza 12 Min., Wäsche 1 Std.
// ============================================================

struct TimerPreset: Codable, Identifiable, Equatable {
    var household_id: String
    var id: String = "p-" + UUID().uuidString.lowercased()
    var name: String
    var icon: String = ""
    var secs: Int
    var position: Int = 0

    var label: String { (icon.isEmpty ? "" : icon + " ") + name }
}

final class TimerPresetStore: ObservableObject {
    static let shared = TimerPresetStore()
    @Published private(set) var presets: [TimerPreset] = []
    private var household: String?
    private let api = SupabaseClient.shared
    private let cacheKey = "timer.presets"

    init() {
        if let d = UserDefaults.standard.data(forKey: cacheKey),
           let list = try? JSONDecoder().decode([TimerPreset].self, from: d) { presets = list }
    }

    private static func defaults(_ h: String) -> [TimerPreset] {
        [TimerPreset(household_id: h, id: "std-eier", name: "Eier", icon: "🥚", secs: 8 * 60, position: 0),
         TimerPreset(household_id: h, id: "std-tee", name: "Tee", icon: "🍵", secs: 4 * 60, position: 1),
         TimerPreset(household_id: h, id: "std-pizza", name: "Pizza", icon: "🍕", secs: 12 * 60, position: 2),
         TimerPreset(household_id: h, id: "std-waesche", name: "Wäsche", icon: "👕", secs: 60 * 60, position: 3)]
    }

    func load(household h: String) async {
        household = h
        guard let rows: [TimerPreset] = try? await api.select("timer_presets", ["household_id": "eq." + h, "order": "position,name"]) else { return }
        let seededKey = "timer.presets.seeded." + h
        if rows.isEmpty && !UserDefaults.standard.bool(forKey: seededKey) {
            // Erstes Mal in diesem Haushalt: Standard-Vorlagen anlegen
            UserDefaults.standard.set(true, forKey: seededKey)
            let std = Self.defaults(h)
            set(std)
            try? await api.upsert("timer_presets", std)
            return
        }
        UserDefaults.standard.set(true, forKey: seededKey)
        set(rows)
    }

    func save(_ p: TimerPreset) {
        var list = presets
        if let i = list.firstIndex(where: { $0.id == p.id }) { list[i] = p } else {
            var n = p; n.position = (list.map(\.position).max() ?? -1) + 1; list.append(n)
        }
        set(list)
        let row = list.first { $0.id == p.id }!
        Task { try? await self.api.upsert("timer_presets", [row]) }
    }

    func delete(_ p: TimerPreset) {
        set(presets.filter { $0.id != p.id })
        Task { try? await self.api.delete("timer_presets", ["household_id": "eq." + p.household_id, "id": "eq." + p.id]) }
    }

    /// Nach vorne holen (Sortieren ohne Ziehen – geht auf iPhone und iPad gleich)
    func moveToFront(_ p: TimerPreset) {
        var list = presets.filter { $0.id != p.id }
        list.insert(p, at: 0)
        for i in list.indices { list[i].position = i }
        set(list)
        let rows = list
        Task { try? await self.api.upsert("timer_presets", rows) }
    }

    func newPreset() -> TimerPreset? {
        guard let h = household ?? TimerCenter.shared.household else { return nil }
        return TimerPreset(household_id: h, name: "", secs: 10 * 60)
    }

    private func set(_ list: [TimerPreset]) {
        let sorted = list.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
        if sorted != presets { presets = sorted }
        if let d = try? JSONEncoder().encode(sorted) { UserDefaults.standard.set(d, forKey: cacheKey) }
    }
}

/// Vorlage anlegen oder bearbeiten
struct PresetEditSheet: View {
    @State var preset: TimerPreset
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Name")
                        TextField("z. B. Nudeln", text: $preset.name).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Symbol")
                        TextField("Emoji", text: Binding(get: { preset.icon }, set: { preset.icon = String($0.suffix(1)) }))
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section {
                    DurationWheel(seconds: $preset.secs)
                        .frame(height: 200).frame(maxWidth: 420).frame(maxWidth: .infinity)
                } header: { Text("Dauer") }
                if !isNew {
                    Section {
                        Button("Nach vorne") { TimerPresetStore.shared.moveToFront(preset); dismiss() }
                        Button("Vorlage löschen", role: .destructive) { TimerPresetStore.shared.delete(preset); dismiss() }
                    }
                }
            }
            .navigationTitle(isNew ? "Neue Vorlage" : "Vorlage").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var p = preset
                        p.name = p.name.trimmingCharacters(in: .whitespaces)
                        TimerPresetStore.shared.save(p); dismiss()
                    }
                    .disabled(preset.name.trimmingCharacters(in: .whitespaces).isEmpty || preset.secs < 5)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
