import SwiftUI

// ============================================================
// Küche, Runde 2: eigene Rezepte (Editor, Link-Import),
// Familien-Kochbuch, Koch-Statistik, Siri-Kurzbefehl.
// ============================================================

// MARK: Rezept-Editor

struct RecipeEditorView: View {
    let original: Recipe?
    var onSaved: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared

    @State private var icon = "🍽️"
    @State private var title = ""
    @State private var cuisine = ""
    @State private var servings = 2
    @State private var minutes = 30
    @State private var airfryer = false
    @State private var ingredients: [Ing] = []
    @State private var steps: [StepRow] = []
    @State private var confirmDelete = false

    struct Ing: Identifiable { let id = UUID(); var amount = ""; var name = "" }
    struct StepRow: Identifiable { let id = UUID(); var text = ""; var minutes = 0 }

    init(recipe: Recipe?, onSaved: ((String) -> Void)? = nil) {
        original = recipe; self.onSaved = onSaved
        guard let r = recipe else {
            _ingredients = State(initialValue: [Ing()]); _steps = State(initialValue: [StepRow()]); return
        }
        _icon = State(initialValue: r.icon); _title = State(initialValue: r.title)
        _cuisine = State(initialValue: r.cuisine ?? ""); _servings = State(initialValue: r.baseServings)
        let m = r.time.flatMap { t in t.range(of: #"\d+"#, options: .regularExpression).map { Int(t[$0]) ?? 30 } } ?? 30
        _minutes = State(initialValue: m); _airfryer = State(initialValue: r.airfryer == true)
        _ingredients = State(initialValue: r.ingredients.map { Ing(amount: $0.amount ?? "", name: $0.name) })
        _steps = State(initialValue: r.steps.map { StepRow(text: $0.text, minutes: Int($0.minutes ?? 0)) })
    }

    private var editingExisting: Bool { original?.isOwn == true }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    TextField("🍽️", text: $icon).font(.system(size: 40)).frame(width: 56).multilineTextAlignment(.center)
                    TextField("Name des Rezepts", text: $title).font(.title3.weight(.semibold))
                }
                TextField("Küche, z. B. Italienisch", text: $cuisine)
                Stepper("\(servings) Portionen", value: $servings, in: 1...20)
                Stepper("ca. \(minutes) Min.", value: $minutes, in: 5...600, step: 5)
                Toggle("Airfryer-Rezept", isOn: $airfryer)
            }
            Section(header: Text("Zutaten"), footer: Text("Menge links (z. B. „200 g“), Zutat rechts. So rechnet Hubert die Portionen um.")) {
                ForEach($ingredients) { $i in
                    HStack {
                        TextField("Menge", text: $i.amount).frame(width: 90)
                        Divider()
                        TextField("Zutat", text: $i.name)
                    }
                }
                .onDelete { ingredients.remove(atOffsets: $0) }
                Button { ingredients.append(Ing()) } label: { Label("Zutat hinzufügen", systemImage: "plus") }
            }
            Section(header: Text("Zubereitung"), footer: Text("Mit Minuten bekommt der Schritt im Kochmodus einen Timer-Knopf.")) {
                ForEach(Array(steps.indices), id: \.self) { i in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schritt \(i + 1)").font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                        TextEditor(text: $steps[i].text).frame(minHeight: 70)
                        Stepper(steps[i].minutes == 0 ? "Kein Timer" : "Timer: \(steps[i].minutes) Min.",
                                value: $steps[i].minutes, in: 0...240).font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { steps.remove(atOffsets: $0) }
                Button { steps.append(StepRow()) } label: { Label("Schritt hinzufügen", systemImage: "plus") }
            }
            if let src = original?.source, !src.isEmpty {
                Section(header: Text("Quelle")) { Text(src).font(.footnote).foregroundColor(Theme.secondary) }
            }
            if editingExisting {
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Rezept löschen", systemImage: "trash") }
                }
            }
        }
        .navigationTitle(editingExisting ? "Rezept bearbeiten" : "Neues Rezept")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { save() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .confirmationDialog("Rezept wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { if let o = original { kitchen.deleteOwn(o.id) }; dismiss() }
        }
    }

    private func save() {
        let r = Recipe(
            id: editingExisting ? original!.id : "",
            title: title.trimmingCharacters(in: .whitespaces), icon: icon.isEmpty ? "🍽️" : String(icon.prefix(2)),
            cuisine: cuisine.isEmpty ? nil : cuisine, servings: servings, time: "ca. \(minutes) Min.",
            ingredients: ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { Recipe.Ingredient(amount: $0.amount, name: $0.name) },
            steps: steps.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { Recipe.Step(text: $0.text, minutes: $0.minutes > 0 ? Double($0.minutes) : nil) },
            airfryer: airfryer ? true : nil, source: original?.source)
        if let id = kitchen.saveOwn(r) { onSaved?(id) }
        dismiss()
    }
}

/// Neues Rezept als Blatt
struct NewRecipeSheet: View {
    var recipe: Recipe? = nil
    var body: some View {
        NavigationView { RecipeEditorView(recipe: recipe) }.navigationViewStyle(.stack)
    }
}

// MARK: Rezept per Link

struct ImportLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var link = ""
    @State private var busy = false
    @State private var error: String?
    @State private var imported: Recipe?

    var body: some View {
        NavigationView {
            if let r = imported {
                RecipeEditorView(recipe: r)
            } else {
                Form {
                    Section(footer: Text("Funktioniert mit den meisten Rezeptseiten, z. B. Chefkoch, Lecker, EatSmarter und vielen Blogs. Danach kannst du alles prüfen und anpassen.")) {
                        HStack {
                            TextField("https://…", text: $link).keyboardType(.URL).textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            Button("Einfügen") { link = UIPasteboard.general.string ?? link }.buttonStyle(.borderless)
                        }
                    }
                    Section {
                        Button {
                            Task {
                                busy = true; error = nil
                                do { imported = try await kitchen.importRecipe(from: link.trimmingCharacters(in: .whitespaces)) }
                                catch { self.error = error.localizedDescription }
                                busy = false
                            }
                        } label: {
                            HStack { if busy { ProgressView().padding(.trailing, 6) }; Text(busy ? "Lade Rezept …" : "Rezept laden").font(.headline) }
                        }
                        .disabled(busy || !link.lowercased().hasPrefix("http"))
                    }
                    if let e = error { Section { Label(e, systemImage: "exclamationmark.triangle").foregroundColor(.orange) } }
                }
                .navigationTitle("Rezept aus Link").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
                .onAppear {
                    if let s = UIPasteboard.general.string, s.hasPrefix("http"), link.isEmpty { link = s }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Familien-Kochbuch

struct CookbookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var code: String?
    @State private var other = ""
    @State private var message: String?
    @State private var copied = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Euer Kochbuch-Code"),
                        footer: Text("Wer diesen Code eingibt, sieht eure eigenen Rezepte – zum Nachkochen und Kopieren. Ändern können sie nur Mitglieder eures Haushalts.")) {
                    HStack {
                        Text(code ?? "…").font(.system(size: 28, weight: .bold, design: .monospaced))
                        Spacer()
                        Button(copied ? "Kopiert" : "Kopieren") { UIPasteboard.general.string = code; copied = true }
                            .buttonStyle(.borderless).disabled(code == nil)
                    }
                    let mine = kitchen.own.filter { $0.householdId == kitchen.household }.count
                    Text(mine == 0 ? "Noch keine eigenen Rezepte" : "\(mine) eigene Rezepte").foregroundColor(Theme.secondary)
                }
                Section(header: Text("Einem Kochbuch folgen"), footer: Text("Code von Familie oder Freunden, z. B. „KB-4F2A9C“.")) {
                    HStack {
                        TextField("KB-…", text: $other).textInputAutocapitalization(.characters).disableAutocorrection(true)
                        Button("Folgen") {
                            Task {
                                do { let n = try await kitchen.follow(code: other); message = "Ihr folgt jetzt dem Kochbuch von „\(n)“."; other = "" }
                                catch { message = error.localizedDescription }
                            }
                        }
                        .buttonStyle(.borderless).disabled(other.count < 5)
                    }
                    if let m = message { Text(m).font(.footnote).foregroundColor(Theme.secondary) }
                }
                if !kitchen.followed.isEmpty {
                    Section(header: Text("Ihr folgt")) {
                        ForEach(kitchen.followed, id: \.sourceId) { c in
                            HStack {
                                Label(c.name, systemImage: "book.closed")
                                Spacer()
                                Text("\(kitchen.own.filter { $0.householdId == c.sourceId }.count) Rezepte").foregroundColor(Theme.secondary)
                            }
                            .swipeActions { Button(role: .destructive) { kitchen.unfollow(c) } label: { Label("Nicht mehr folgen", systemImage: "xmark") } }
                        }
                    }
                }
            }
            .navigationTitle("Familien-Kochbuch").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .task { code = await kitchen.cookbookCode() }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Koch-Statistik

struct KitchenStatsView: View {
    /// Rezept antippen → Statistik schließt sich, das Rezept öffnet sich in der Küche
    var onOpen: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared

    private var events: [CookedEvent] { kitchen.cooked.sorted { $0.date > $1.date } }

    private func count(since days: Int) -> Int {
        let from = Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: Date()))!
        return events.filter { $0.date >= from }.count
    }

    /// Tage am Stück mit Kochen (heute oder gestern beginnend)
    private var streak: Int {
        let days = Set(events.map { Calendar.current.startOfDay(for: $0.date) })
        var d = Calendar.current.startOfDay(for: Date())
        if !days.contains(d) { d = Calendar.current.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while days.contains(d) { n += 1; d = Calendar.current.date(byAdding: .day, value: -1, to: d)! }
        return n
    }

    /// Gekocht pro Woche, letzte 8 Wochen (älteste zuerst)
    private var weeks: [(String, Int)] {
        let cal = Calendar(identifier: .iso8601)
        let start = cal.dateInterval(of: .weekOfYear, for: Date())!.start
        return (0..<8).reversed().map { i in
            let from = cal.date(byAdding: .weekOfYear, value: -i, to: start)!
            let to = cal.date(byAdding: .weekOfYear, value: 1, to: from)!
            return ("KW \(cal.component(.weekOfYear, from: from))", events.filter { $0.date >= from && $0.date < to }.count)
        }
    }

    private var top: [(RecipeSummary, Int)] {
        kitchen.meta.values.filter { $0.cookedCount > 0 }.sorted { $0.cookedCount > $1.cookedCount }.prefix(5)
            .compactMap { m in kitchen.summary(m.recipeId).map { ($0, m.cookedCount) } }
    }

    /// Zuletzt gekocht: die letzten 5 verschiedenen Rezepte
    private var recent: [(RecipeSummary, Date)] {
        var seen = Set<String>()
        var out: [(RecipeSummary, Date)] = []
        for e in events where !seen.contains(e.recipeId) {
            seen.insert(e.recipeId)
            if let s = kitchen.summary(e.recipeId) { out.append((s, e.date)) }
            if out.count == 5 { break }
        }
        return out
    }

    private func when(_ d: Date) -> String {
        let days = -Fmt.dayDiff(d)
        return days <= 0 ? "heute" : days == 1 ? "gestern" : "vor \(days) Tagen"
    }

    private func open(_ id: String) {
        onOpen?(id)
        dismiss()
    }

    /// Antippbare Zeile: Symbol, Titel, rechts Wert und Pfeil
    private func recipeRow(_ r: RecipeSummary, _ trailing: String) -> some View {
        Button { open(r.id) } label: {
            HStack(spacing: 10) {
                Text(r.icon)
                Text(r.title).lineLimit(1).foregroundColor(.primary)
                Spacer(minLength: 8)
                Text(trailing).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundColor(Theme.secondary)
                    .lineLimit(1).layoutPriority(1)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Rezept öffnen")
    }

    private var cuisines: [(String, Int)] {
        var c: [String: Int] = [:]
        for e in events { if let s = kitchen.summary(e.recipeId) { c[s.cuisine ?? "Sonstige", default: 0] += 1 } }
        return c.sorted { $0.value > $1.value }.prefix(6).map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if events.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.bar.xaxis").font(.system(size: 44)).foregroundColor(Theme.secondary)
                            Text("Noch nichts gekocht").font(.headline)
                            Text("Im Kochmodus am Ende auf „Gekocht – fertig“ tippen – dann füllt sich die Statistik.")
                                .multilineTextAlignment(.center).foregroundColor(Theme.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            tile("Diese Woche", "\(count(since: 6))", "mal gekocht")
                            tile("30 Tage", "\(count(since: 29))", "mal gekocht")
                            tile("Serie", "\(streak)", streak == 1 ? "Tag am Stück" : "Tage am Stück")
                            tile("Rezepte", "\(Set(events.map { $0.recipeId }).count)", "verschiedene")
                        }
                        card("PRO WOCHE") { bars(weeks) }
                        if !top.isEmpty {
                            card("AM HÄUFIGSTEN GEKOCHT") {
                                ForEach(Array(top.enumerated()), id: \.offset) { i, t in
                                    if i > 0 { Divider() }
                                    recipeRow(t.0, "\(t.1)×")
                                }
                            }
                        }
                        if !recent.isEmpty {
                            card("ZULETZT GEKOCHT") {
                                ForEach(Array(recent.enumerated()), id: \.offset) { i, t in
                                    if i > 0 { Divider() }
                                    recipeRow(t.0, when(t.1))
                                }
                            }
                        }
                        if !cuisines.isEmpty { card("KÜCHEN-MIX") { bars(cuisines, horizontal: true) } }
                    }
                }
                .padding()
                .frame(maxWidth: 820).frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Koch-Statistik").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }

    private func tile(_ title: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
            Text(value).font(.system(size: 34, weight: .bold).monospacedDigit())
            Text(sub).font(.footnote).foregroundColor(Theme.secondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    private func card<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
            c()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    /// Einfache Balken (Swift Charts gibt es erst ab iOS 16)
    @ViewBuilder private func bars(_ data: [(String, Int)], horizontal: Bool = false) -> some View {
        let maxV = max(1, data.map { $0.1 }.max() ?? 1)
        if horizontal {
            VStack(spacing: 8) {
                ForEach(data, id: \.0) { d in
                    HStack(spacing: 10) {
                        Text(d.0).font(.subheadline).frame(width: 110, alignment: .leading).lineLimit(1)
                        GeometryReader { g in
                            Capsule().fill(Theme.accent).frame(width: max(6, g.size.width * CGFloat(d.1) / CGFloat(maxV)))
                        }
                        .frame(height: 12)
                        Text("\(d.1)").font(.subheadline.monospacedDigit()).frame(width: 28, alignment: .trailing)
                    }
                }
            }
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.0) { d in
                    VStack(spacing: 4) {
                        Text(d.1 > 0 ? "\(d.1)" : "").font(.caption2.monospacedDigit()).foregroundColor(Theme.secondary)
                        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(d.1 > 0 ? Theme.accent : Color(UIColor.tertiarySystemFill))
                            .frame(height: max(4, 110 * CGFloat(d.1) / CGFloat(maxV)))
                        Text(d.0).font(.caption2).foregroundColor(Theme.secondary).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150, alignment: .bottom)
        }
    }
}

// MARK: Siri-Kurzbefehl

struct SiriSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var kitchen = KitchenStore.shared
    @State private var url: String?
    @State private var busy = false
    @State private var error: String?
    @State private var copied = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    Label("„Hey Siri, Einkauf“ – dann sagst du z. B. „Milch und Eier“. Das landet sofort auf der gemeinsamen Liste, auch vom iPhone und ohne Hubert zu öffnen.",
                          systemImage: "mic.fill")
                }
                Section(header: Text("1. Persönlichen Link erzeugen"),
                        footer: Text("Der Link enthält einen geheimen Schlüssel für eure Einkaufsliste. Neu erzeugen macht alte Links ungültig.")) {
                    if let u = url {
                        Text(u).font(.footnote.monospaced()).textSelection(.enabled)
                        Button { UIPasteboard.general.string = u; copied = true } label: {
                            Label(copied ? "Kopiert" : "Link kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                    }
                    Button {
                        Task {
                            busy = true; error = nil
                            do { url = KitchenStore.shortcutURL + "?t=" + (try await kitchen.newShortcutToken()); copied = false }
                            catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    } label: {
                        HStack { if busy { ProgressView().padding(.trailing, 6) }; Text(url == nil ? "Link erzeugen" : "Neuen Link erzeugen") }
                    }
                    if let e = error { Text(e).foregroundColor(.orange) }
                }
                Section(header: Text("2. Kurzbefehl anlegen (einmalig)")) {
                    step(1, "App „Kurzbefehle“ öffnen und oben auf + tippen.")
                    step(2, "Aktion „Nach Eingabe fragen“ hinzufügen. Frage: „Was soll auf die Liste?“")
                    step(3, "Aktion „Inhalte von URL abrufen“ hinzufügen und den kopierten Link als URL einfügen.")
                    step(4, "Dort „Mehr anzeigen“: Methode POST, Anfragetext JSON, Feld „item“ (Text) = „Bereitgestellte Eingabe“.")
                    step(5, "Aktion „Text sprechen“ (oder „Ergebnis zeigen“) mit „Inhalte der URL“ hinzufügen.")
                    step(6, "Oben den Namen „Einkauf“ geben. Fertig – „Hey Siri, Einkauf“.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Mit Siri hinzufügen").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.subheadline.weight(.bold)).foregroundColor(.white)
                .frame(width: 24, height: 24).background(Circle().fill(Theme.accent))
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
