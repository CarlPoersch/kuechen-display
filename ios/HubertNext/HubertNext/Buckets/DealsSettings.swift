import SwiftUI

// ============================================================
// Deals einstellen – so einfach wie möglich:
//  1. Bereiche antippen (Mode, Schuhe, Make-up …) → passende Suchen sind vorgewählt
//  2. Feiner: je Bereich einzelne Suchen an/aus, eigene Wörter eintippen
//     (mit Vorschau), je Suche Höchstpreis, „passt auch auf“, „nicht passend“
// ============================================================

/// In den Karten-Einstellungen (auch bei der Einrichtung und „Neu in Hubert“)
struct DealsSettings: View {
    @Binding var config: [String: JSON]

    private var watch: [DealWatch] { DealsBucket.watch(config) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Was suchst du?").font(.headline)
            Text("Tippe Bereiche an – Hubert wählt passende Suchen vor.").font(.caption).foregroundColor(Theme.secondary)
            DealAreaGrid(config: $config)
        }
        .padding(.vertical, 6)
        NavigationLink(destination: DealWatchView(config: $config)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Suchen, Shops & Preise")
                Text(watch.isEmpty ? "Eigene Wörter, Marken, Höchstpreise"
                     : watch.map(\.t).prefix(4).joined(separator: ", ") + (watch.count > 4 ? " +\(watch.count - 4)" : ""))
                    .font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
            }
        }
        Toggle(isOn: Binding(get: { DealsBucket.minTemp(config) >= 100 }, set: { config["min"] = .number($0 ? 100 : 0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nur sehr beliebte Deals")
                Text("Ab 100° – von der mydealz-Community gefeiert").font(.caption).foregroundColor(Theme.secondary)
            }
        }
        Toggle(isOn: Binding(get: { DealsBucket.showHot(config) }, set: { config["hot"] = .bool($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heiße Deals zeigen, wenn nichts passt")
                Text("Damit die Karte nie leer ist").font(.caption).foregroundColor(Theme.secondary)
            }
        }
    }
}

/// Raster der Bereiche – antippen wählt die Startvorschläge des Bereichs (nochmal antippen: alle aus)
struct DealAreaGrid: View {
    @Binding var config: [String: JSON]
    @ObservedObject private var service = DealService.shared

    private var watch: [DealWatch] { DealsBucket.watch(config) }
    private func count(_ a: DealCatalog) -> Int { watch.filter { DealsBucket.area(of: $0) == a.id }.count }

    private func toggle(_ a: DealCatalog) {
        var l = watch
        if count(a) > 0 {
            l.removeAll { DealsBucket.area(of: $0) == a.id }
        } else {
            for i in a.starters where !l.contains(where: { $0.t.caseInsensitiveCompare(i.t) == .orderedSame }) {
                l.append(DealWatch(t: i.t, area: a.id))
            }
        }
        DealsBucket.store(l, in: &config)
    }

    var body: some View {
        Group {
            if service.catalog.isEmpty {
                HStack(spacing: 10) { ProgressView(); Text("Lädt Bereiche …").foregroundColor(Theme.secondary) }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 10)], spacing: 10) {
                    ForEach(service.catalog) { a in
                        let n = count(a)
                        Button { withAnimation(.easeOut(duration: 0.15)) { toggle(a) } } label: {
                            VStack(spacing: 6) {
                                DealAreaIcon(area: a.id, size: 40, filled: n > 0)
                                Text(a.name).font(.caption.weight(.semibold)).foregroundColor(.primary)
                                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                                Text(n > 0 ? "\(n) gewählt" : " ").font(.caption2).foregroundColor(Theme.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 104)
                            .padding(.horizontal, 4)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(n > 0 ? DealArea.color(a.id).opacity(0.14) : Color(UIColor.tertiarySystemFill)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(a.name + (n > 0 ? ", \(n) Suchen gewählt" : ""))
                    }
                }
            }
        }
        .task { await service.loadCatalog() }
    }
}

/// Alle Suchen: eigene eintippen, je Bereich an/aus
struct DealWatchView: View {
    @Binding var config: [String: JSON]
    @ObservedObject private var service = DealService.shared
    @State private var text = ""
    @State private var preview: DealPreview?
    @State private var loading = false

    private var watch: [DealWatch] { DealsBucket.watch(config) }
    private func save(_ w: [DealWatch]) { DealsBucket.store(w, in: &config) }
    private var query: String { text.trimmingCharacters(in: .whitespaces) }
    private func has(_ t: String) -> Bool { watch.contains { $0.t.caseInsensitiveCompare(t) == .orderedSame } }

    private func add(_ t: String) {
        let t = t.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2, !has(t) else { text = ""; return }
        save(watch + [DealWatch(t: t)])
        text = ""; preview = nil
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.secondary)
                    TextField("Eigene Suche, z. B. Strickkleid oder Airfryer", text: $text)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit { add(query) }
                    if query.count >= 2 {
                        Button("Hinzufügen") { withAnimation { add(query) } }.buttonStyle(.borderless)
                    }
                }
                if query.count >= 2 {
                    if loading && preview == nil {
                        HStack(spacing: 10) { ProgressView(); Text("Suche passende Deals …").foregroundColor(Theme.secondary) }
                    } else if let p = preview {
                        Text(p.n == 0 ? "Gerade kein passender Deal – Hubert zeigt ihn, sobald einer auftaucht."
                             : "\(p.n) passende \(p.n == 1 ? "Deal" : "Deals") gerade")
                            .font(.subheadline).foregroundColor(Theme.secondary)
                        ForEach(p.deals.prefix(3)) { d in DealRow(deal: d, compact: true) }
                        if !p.std.alts.isEmpty {
                            Text("Sucht automatisch auch: " + p.std.alts.prefix(6).joined(separator: ", ")).font(.caption).foregroundColor(Theme.secondary)
                        }
                    }
                }
            } footer: {
                Text("Groß/klein, Umlaute, Mehrzahl und kleine Tippfehler sind egal.")
            }

            Section {
                if watch.isEmpty { Text("Noch keine – unten Bereiche öffnen oder oben eintippen.").foregroundColor(Theme.secondary) }
                ForEach(watch) { w in
                    NavigationLink(destination: DealTermEdit(config: $config, id: w.id)) {
                        HStack(spacing: 12) {
                            DealAreaIcon(area: DealsBucket.area(of: w), size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.t)
                                Text(w.summary).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                .onDelete { idx in var l = watch; l.remove(atOffsets: idx); save(l) }
                .onMove { from, to in var l = watch; l.move(fromOffsets: from, toOffset: to); save(l) }
            } header: { Text("Meine Suchen") } footer: {
                if !watch.isEmpty { Text("Antippen: Höchstpreis und genauere Wörter. Wischen entfernt. Die Reihenfolge gilt auch für „Alle Deals“.") }
            }

            Section(header: Text("Bereiche")) {
                ForEach(service.catalog) { a in
                    let n = watch.filter { DealsBucket.area(of: $0) == a.id }.count
                    NavigationLink(destination: DealAreaView(config: $config, areaId: a.id)) {
                        HStack(spacing: 12) {
                            DealAreaIcon(area: a.id, size: 28)
                            Text(a.name)
                            Spacer()
                            if n > 0 { Text("\(n) von \(a.items.count)").foregroundColor(Theme.secondary) }
                        }
                    }
                }
                if service.catalog.isEmpty { HStack(spacing: 10) { ProgressView(); Text("Lädt …").foregroundColor(Theme.secondary) } }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Suchen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !watch.isEmpty { EditButton() }
            }
        }
        .task { await service.loadCatalog() }
        .task(id: query) {
            guard query.count >= 2 else { preview = nil; loading = false; return }
            loading = true
            try? await Task.sleep(nanoseconds: 400_000_000)     // erst nach kurzer Tipp-Pause
            guard !Task.isCancelled else { return }
            let p = try? await service.preview(DealWatch(t: query), min: DealsBucket.minTemp(config))
            guard !Task.isCancelled else { return }
            preview = p
            loading = false
        }
    }
}

/// Ein Bereich: Suchen an/aus
struct DealAreaView: View {
    @Binding var config: [String: JSON]
    let areaId: String
    @ObservedObject private var service = DealService.shared

    private var area: DealCatalog? { service.catalog.first { $0.id == areaId } }
    private var watch: [DealWatch] { DealsBucket.watch(config) }
    private func has(_ t: String) -> Bool { watch.contains { $0.t.caseInsensitiveCompare(t) == .orderedSame } }

    private func toggle(_ t: String) {
        var l = watch
        if has(t) { l.removeAll { $0.t.caseInsensitiveCompare(t) == .orderedSame } } else { l.append(DealWatch(t: t, area: areaId)) }
        DealsBucket.store(l, in: &config)
    }

    var body: some View {
        List {
            if let a = area {
                Section {
                    VStack(spacing: 8) {
                        DealAreaIcon(area: a.id, size: 56)
                        Text(a.name).font(.title2.weight(.bold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(a.items, id: \.t) { i in
                        Button { withAnimation { toggle(i.t) } } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(i.t).foregroundColor(.primary)
                                    if !i.alts.isEmpty {
                                        Text("auch " + i.alts.prefix(4).joined(separator: ", ")).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: has(i.t) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundColor(has(i.t) ? Theme.accent : Color(UIColor.tertiaryLabel))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(i.t + (has(i.t) ? ", gewählt" : ""))
                    }
                } footer: {
                    Text("Jede Suche findet auch verwandte Wörter – „Kleider“ zum Beispiel auch Maxikleid und Strickkleid.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(area?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DealTermEdit: View {
    @Binding var config: [String: JSON]
    let id: String
    @ObservedObject private var service = DealService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newAlt = ""
    @State private var newNot = ""
    @State private var maxText = ""
    @State private var preview: DealPreview?

    private var item: DealWatch? { DealsBucket.watch(config).first { $0.id == id } }

    private func update(_ change: (inout DealWatch) -> Void) {
        var l = DealsBucket.watch(config)
        guard let i = l.firstIndex(where: { $0.id == id }) else { return }
        change(&l[i])
        DealsBucket.store(l, in: &config)
    }

    /// Ändert sich etwas, wird die Vorschau neu geladen
    private var previewKey: String { item.map { DealService.key([$0], min: DealsBucket.minTemp(config)) } ?? "" }

    var body: some View {
        List {
            if let w = item {
                Section(header: Text("Stichwort")) {
                    TextField("Stichwort", text: Binding(get: { w.t }, set: { v in update { $0.t = v } }))
                        .disableAutocorrection(true)
                }

                Section {
                    HStack {
                        Text("Höchstens")
                        TextField("kein Limit", text: $maxText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: maxText) { v in
                                let n = Double(v.replacingOccurrences(of: ",", with: "."))
                                update { $0.max = (n ?? 0) > 0 ? n : nil }
                            }
                        Text("€").foregroundColor(Theme.secondary)
                    }
                } header: { Text("Preis") } footer: { Text("Leer lassen = jeder Preis. Mit Limit zeigt Hubert nur Deals mit bekanntem Preis.") }

                Section {
                    ForEach(w.alts, id: \.self) { a in
                        HStack {
                            Text(a)
                            Spacer()
                            Button { update { $0.alts.removeAll { $0 == a } } } label: { Image(systemName: "minus.circle.fill").foregroundColor(.red) }
                                .buttonStyle(.borderless).accessibilityLabel("\(a) entfernen")
                        }
                    }
                    addRow("Weiteres Wort, z. B. Earbuds", $newAlt) { v in update { $0.alts.append(v) } }
                } header: { Text("Passt auch auf") } footer: {
                    if let s = preview?.std.alts, !s.isEmpty { Text("Automatisch dabei: " + s.joined(separator: ", ")) }
                    else { Text("Hubert sucht dann nach jedem dieser Wörter.") }
                }

                Section {
                    ForEach(w.not, id: \.self) { a in
                        HStack {
                            Text(a)
                            Spacer()
                            Button { update { $0.not.removeAll { $0 == a } } } label: { Image(systemName: "minus.circle.fill").foregroundColor(.red) }
                                .buttonStyle(.borderless).accessibilityLabel("\(a) entfernen")
                        }
                    }
                    addRow("Ausschließen, z. B. Hülle", $newNot) { v in update { $0.not.append(v) } }
                } header: { Text("Nicht passend") } footer: {
                    if let s = preview?.std.not, !s.isEmpty { Text("Automatisch ausgeschlossen: " + s.joined(separator: ", ")) }
                    else { Text("Deals mit diesen Wörtern im Titel blendet Hubert aus.") }
                }

                Section {
                    if let p = preview {
                        if p.deals.isEmpty { Text("Gerade nichts – Hubert schaut alle 10 Minuten nach.").foregroundColor(Theme.secondary) }
                        ForEach(p.deals) { d in
                            NavigationLink(destination: DealDetailView(deal: d, terms: [w.t])) { DealRow(deal: d, compact: true) }
                        }
                    } else {
                        HStack(spacing: 10) { ProgressView(); Text("Lädt …").foregroundColor(Theme.secondary) }
                    }
                } header: { Text(preview.map { "Gerade passend (\($0.n))" } ?? "Gerade passend") }

                Section {
                    Button(role: .destructive) {
                        DealsBucket.store(DealsBucket.watch(config).filter { $0.id != id }, in: &config)
                        dismiss()
                    } label: { Text("Stichwort entfernen").frame(maxWidth: .infinity) }
                }
            } else {
                Text("Nicht mehr in deiner Auswahl").foregroundColor(Theme.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item?.t ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if let m = item?.max { maxText = DealFmt.plain(m) } }
        .task(id: previewKey) {
            guard let w = item else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            if let p = try? await service.preview(w, min: DealsBucket.minTemp(config)), !Task.isCancelled { preview = p }
        }
    }

    private func addRow(_ prompt: String, _ text: Binding<String>, _ add: @escaping (String) -> Void) -> some View {
        HStack {
            Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent)
            TextField(prompt, text: text)
                .disableAutocorrection(true)
                .submitLabel(.done)
                .onSubmit {
                    let v = text.wrappedValue.trimmingCharacters(in: .whitespaces)
                    if v.count >= 2 { withAnimation { add(v) } }
                    text.wrappedValue = ""
                }
        }
    }
}
