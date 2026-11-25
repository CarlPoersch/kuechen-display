import SwiftUI

// ============================================================
// Woche würfeln: für die freien Tage der nächsten 7 Tage je ein Hauptgericht.
// Logik statt reinem Zufall:
//  - nichts, was in den letzten 14 Tagen gekocht wurde oder schon im Plan steht
//  - unter der Woche schnelle Gerichte (bis 40 Min.), am Wochenende darf es länger dauern
//  - Abwechslung: nie zweimal hintereinander dieselbe Küche oder dasselbe Fleisch, höchstens 2× dieselbe Küche
//  - Fleischfrei-Tage (wenn alles erlaubt ist), Favoriten und gut Bewertetes öfter, Vorrat zuerst
// Einzelne Tage lassen sich neu würfeln oder festhalten; „Übernehmen“ trägt alles in den Wochenplan ein.
// ============================================================

struct WeekDiceSheet: View {
    let days: [Date]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared

    @State private var selected: Set<String> = []
    @State private var picks: [String: String] = [:]        // Tag → Rezept
    @State private var locked: Set<String> = []
    @State private var diet = DietPreference.kitchen
    @AppStorage("hubert.dice.quick") private var quick = true
    @AppStorage("hubert.dice.veggie") private var veggieDays = 2
    @AppStorage("hubert.dice.favs") private var favs = true
    @AppStorage("hubert.dice.pantry") private var usePantry = true
    @AppStorage("hubert.dice.soup") private var soups = false
    @AppStorage("hubert.dice.portions") private var portions = 2
    @State private var started = false

    private func key(_ d: Date) -> String { KitchenStore.day.string(from: d) }
    private var chosenDays: [Date] { days.filter { selected.contains(key($0)) } }

    var body: some View {
        NavigationView {
            List {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 8) {
                        ForEach(days, id: \.self) { d in dayChip(d) }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tage")
                } footer: {
                    Text("Ein Punkt heißt: An dem Tag ist schon etwas geplant.")
                }

                Section {
                    if chosenDays.isEmpty {
                        Text("Wähle oben mindestens einen Tag.").foregroundColor(Theme.secondary)
                    }
                    ForEach(chosenDays, id: \.self) { d in pickRow(d) }
                } header: {
                    Text("Vorschlag")
                } footer: {
                    if let s = summary { Text(s) }
                }

                Section {
                    Button { withAnimation { roll(all: true) } } label: {
                        Label("Alles neu würfeln", systemImage: "die.face.5").font(.headline)
                    }
                    .disabled(chosenDays.isEmpty)
                }

                Section {
                    Picker("Ernährung", selection: $diet) {
                        ForEach(RecipeFilter.diets, id: \.self) { Text($0).tag($0) }
                    }
                    if diet == "Alle" || diet == "Ohne Fleisch" {
                        Stepper(value: $veggieDays, in: 0...7) {
                            HStack {
                                Text("Vegetarische Tage")
                                Spacer()
                                Text("mind. \(veggieDays)").foregroundColor(Theme.secondary).monospacedDigit()
                            }
                        }
                    }
                    Toggle("Unter der Woche schnell (bis 40 Min.)", isOn: $quick)
                    Toggle("Favoriten öfter", isOn: $favs)
                    Toggle("Vorrat zuerst verbrauchen", isOn: $usePantry)
                    Toggle("Auch Suppen und Eintöpfe", isOn: $soups)
                    Stepper(value: $portions, in: 1...12) {
                        HStack {
                            Text("Portionen")
                            Spacer()
                            Text("\(portions)").foregroundColor(Theme.secondary).monospacedDigit()
                        }
                    }
                } header: {
                    Text("Regeln")
                } footer: {
                    Text("Nicht dabei: was ihr in den letzten 14 Tagen gekocht habt oder schon geplant ist. Am Wochenende darf es länger dauern.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Woche würfeln").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { apply() }.disabled(picks.filter { selected.contains($0.key) }.isEmpty)
                }
            }
            .onAppear {
                guard !started else { return }
                started = true
                // Vorbelegt: die Tage, an denen noch nichts geplant ist
                selected = Set(days.filter { kitchen.planned(on: $0).isEmpty }.map(key))
                roll(all: true)
            }
            .onChange(of: diet) { _ in roll(all: false) }
            .onChange(of: quick) { _ in roll(all: false) }
            .onChange(of: veggieDays) { _ in roll(all: false) }
            .onChange(of: favs) { _ in roll(all: false) }
            .onChange(of: usePantry) { _ in roll(all: false) }
            .onChange(of: soups) { _ in roll(all: false) }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: Bausteine

    private static let weekday: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EE"; return f
    }()

    private func dayChip(_ d: Date) -> some View {
        let k = key(d), on = selected.contains(k)
        let busy = !kitchen.planned(on: d).isEmpty
        return Button {
            withAnimation {
                if on { selected.remove(k); locked.remove(k) } else { selected.insert(k); roll(day: k) }
            }
        } label: {
            VStack(spacing: 2) {
                Text(Self.weekday.string(from: d).replacingOccurrences(of: ".", with: ""))
                    .font(.caption.weight(.semibold))
                Text("\(Calendar.current.component(.day, from: d))").font(.headline.monospacedDigit())
                Circle().fill(busy ? (on ? Color.white : Theme.accent) : Color.clear).frame(width: 5, height: 5)
            }
            .foregroundColor(on ? .white : .primary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(on ? Theme.accent : Color(UIColor.tertiarySystemFill)))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Fmt.dayLabel(d) + (on ? ", ausgewählt" : "") + (busy ? ", schon etwas geplant" : ""))
    }

    private func pickRow(_ d: Date) -> some View {
        let k = key(d)
        let r = picks[k].flatMap { kitchen.summary($0) }
        let isLocked = locked.contains(k)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.dayLabel(d).uppercased()).font(.caption2.weight(.semibold)).foregroundColor(Theme.secondary)
                if let r = r {
                    HStack(spacing: 8) {
                        Text(r.icon).font(.title3)
                        Text(r.title).font(.body.weight(.semibold)).lineLimit(2)
                    }
                    Text(meta(r)).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                } else {
                    Text("Kein passendes Rezept").foregroundColor(Theme.secondary)
                }
            }
            Spacer(minLength: 4)
            Button { withAnimation { if isLocked { locked.remove(k) } else if r != nil { locked.insert(k) } } } label: {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .font(.body.weight(.semibold))
                    .foregroundColor(isLocked ? Theme.accent : Theme.secondary)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isLocked ? "Festgehalten – lösen" : "Festhalten")
            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { roll(day: k) } } label: {
                Image(systemName: "die.face.5")
                    .font(.body.weight(.semibold)).foregroundColor(isLocked ? Color(UIColor.tertiaryLabel) : Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.accent.opacity(isLocked ? 0 : 0.12)))
                    .contentShape(Circle())
            }
            .buttonStyle(.borderless)
            .disabled(isLocked)
            .accessibilityLabel("Diesen Tag neu würfeln")
        }
        .padding(.vertical, 2)
    }

    private func meta(_ r: RecipeSummary) -> String {
        var parts: [String] = []
        if let c = r.cuisine { parts.append(c) }
        if let m = r.minutes {
            let h = m / 60, rest = m % 60
            parts.append(h == 0 ? "\(m) Min." : rest == 0 ? "\(h) Std." : "\(h) Std. \(rest) Min.")
        }
        if let k = r.kcal { parts.append("\(k) kcal") }
        if isVeggie(r) { parts.append("vegetarisch") }
        return parts.joined(separator: " · ")
    }

    /// „Ø 640 kcal · 3 vegetarisch · 5 Küchen“
    private var summary: String? {
        let list = chosenDays.compactMap { picks[key($0)] }.compactMap { kitchen.summary($0) }
        guard !list.isEmpty else { return nil }
        let kc = list.compactMap(\.kcal)
        var parts: [String] = []
        if !kc.isEmpty { parts.append("Ø \(kc.reduce(0, +) / kc.count) kcal pro Portion") }
        parts.append("\(list.filter { isVeggie($0) }.count) vegetarisch")
        parts.append("\(Set(list.map { $0.cuisine ?? "" }).count) Küchen")
        return parts.joined(separator: " · ") + ". Schloss = festhalten, Würfel = nur diesen Tag neu."
    }

    // MARK: Logik

    private func isVeggie(_ r: RecipeSummary) -> Bool {
        let d = r.diet ?? DietGuess.diet(r.ing ?? [])
        return d == "vegetarisch" || d == "vegan"
    }

    private static let proteins = ["hähnchen", "huhn", "pute", "rind", "schwein", "hack", "lamm", "lachs", "garnele",
                                   "thunfisch", "kabeljau", "tofu", "kichererbse", "linse", "speck", "wurst", "ente"]

    /// Hauptzutat, damit nicht zweimal hintereinander Hähnchen kommt
    private func protein(_ r: RecipeSummary) -> String? {
        let ing = (r.ing ?? []).joined(separator: " ").lowercased()
        return Self.proteins.first { ing.contains($0) }
    }

    private func isWeekend(_ k: String) -> Bool {
        guard let d = KitchenStore.day.date(from: k) else { return false }
        let w = Calendar.current.component(.weekday, from: d)
        return w == 1 || w == 7
    }

    /// Grundmenge: Hauptgerichte passend zur Ernährung, nicht kürzlich gekocht, nicht schon geplant
    private func pool() -> [RecipeSummary] {
        let recent = Date().addingTimeInterval(-14 * 86400)
        let planned = Set(kitchen.plan.map(\.recipeId))
        return kitchen.recipes.filter { r in
            let cat = r.cat ?? "Hauptgericht"
            guard cat == "Hauptgericht" || (soups && cat == "Suppe") else { return false }
            guard RecipeFilter.fits(r, diet: diet) else { return false }
            if planned.contains(r.id) { return false }
            if let d = kitchen.meta[r.id]?.lastCookedDate, d > recent { return false }
            return true
        }
    }

    private func weights(_ list: [RecipeSummary]) -> [String: Double] {
        let pantryKeys = usePantry ? kitchen.pantry.map { FoodCatalog.key($0.name) } : []
        var out: [String: Double] = [:]
        for r in list {
            var w = 1.0
            let m = kitchen.meta[r.id]
            if favs && m?.favorite == true { w *= 3 }
            if let s = m?.rating { w *= s >= 4 ? 2 : s <= 2 ? 0.3 : 1 }
            if usePantry && !pantryKeys.isEmpty {
                let miss = PantryMatch.missing(r, pantry: pantryKeys).count
                w *= miss <= 1 ? 3 : miss <= 3 ? 1.6 : 1
            }
            out[r.id] = w
        }
        return out
    }

    private func weighted(_ list: [RecipeSummary], _ w: [String: Double]) -> RecipeSummary? {
        let total = list.reduce(0.0) { $0 + (w[$1.id] ?? 1) }
        guard total > 0 else { return list.randomElement() }
        var x = Double.random(in: 0..<total)
        for r in list {
            x -= w[r.id] ?? 1
            if x < 0 { return r }
        }
        return list.last
    }

    /// Alle offenen Tage neu (all) oder nur die, die zu den neuen Regeln nicht mehr passen
    private func roll(all: Bool) {
        let base = pool()
        let ids = Set(base.map(\.id))
        for d in chosenDays {
            let k = key(d)
            if locked.contains(k) { continue }
            if all || picks[k].map({ !ids.contains($0) }) ?? true { picks[k] = nil }
        }
        fill(base)
    }

    private func roll(day k: String) {
        guard !locked.contains(k) else { return }
        let before = picks[k]
        picks[k] = nil
        fill(pool(), avoid: before)
    }

    /// Leere Tage der Reihe nach füllen – mit Blick auf die Nachbartage
    private func fill(_ base: [RecipeSummary], avoid: String? = nil) {
        let w = weights(base)
        let order = chosenDays.map(key)
        let byId = Dictionary(base.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func pick(_ k: String) -> RecipeSummary? { picks[k].flatMap { byId[$0] ?? kitchen.summary($0) } }
        // Fleischfrei-Tage: so viele, wie noch fehlen – zufällig auf die offenen Tage verteilt
        let openKeys = order.filter { picks[$0] == nil }
        let vegHave = order.compactMap { pick($0) }.filter { isVeggie($0) }.count
        let vegNeed = (diet == "Alle" || diet == "Ohne Fleisch") ? max(0, min(veggieDays, order.count) - vegHave) : 0
        let vegDays = Set(openKeys.shuffled().prefix(vegNeed))

        for (i, k) in order.enumerated() where picks[k] == nil {
            let used = Set(order.compactMap { picks[$0] })
            let prev = i > 0 ? pick(order[i - 1]) : nil
            let next = i + 1 < order.count ? pick(order[i + 1]) : nil
            var cuisineCount: [String: Int] = [:]
            for o in order { if let r = pick(o) { cuisineCount[r.cuisine ?? "", default: 0] += 1 } }
            let needVeg = vegDays.contains(k)

            let all = base.filter { !used.contains($0.id) && $0.id != avoid }
            // Regeln der Reihe nach lockern, bis etwas übrig bleibt
            let strict = all.filter { r in
                if needVeg && !isVeggie(r) { return false }
                if quick && !isWeekend(k), (r.minutes ?? 45) > 40 { return false }
                let c = r.cuisine ?? ""
                if c == prev?.cuisine ?? "§" || c == next?.cuisine ?? "§" { return false }
                if cuisineCount[c, default: 0] >= 2 { return false }
                if let p = protein(r), p == prev.flatMap({ protein($0) }) || p == next.flatMap({ protein($0) }) { return false }
                return true
            }
            let looser = all.filter { r in
                (!needVeg || isVeggie(r)) && (!quick || isWeekend(k) || (r.minutes ?? 45) <= 40)
            }
            let list = !strict.isEmpty ? strict : !looser.isEmpty ? looser : all
            picks[k] = weighted(list, w)?.id ?? (avoid.flatMap { byId[$0] }?.id)
        }
    }

    private func apply() {
        for d in chosenDays {
            if let id = picks[key(d)] { kitchen.addToPlan(id, on: d, portions: portions) }
        }
        dismiss()
    }
}
