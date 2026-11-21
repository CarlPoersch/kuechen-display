import SwiftUI

// ============================================================
// Deals einstellen – wie die Grundliste beim Einkaufszettel:
//  • Vorschläge antippen (mit Synonymen, z. B. Kopfhörer → AirPods, Earbuds)
//  • eigene Stichwörter eintippen – mit Vorschau, was gerade passt
//  • je Stichwort: Höchstpreis, „passt auch auf“, „nicht passend“
// ============================================================

/// Zeilen in den Karten-Einstellungen
struct DealsSettings: View {
    @Binding var config: [String: JSON]

    private var watch: [DealWatch] { DealsBucket.watch(config) }

    var body: some View {
        NavigationLink(destination: DealWatchView(config: $config)) {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill").foregroundColor(.red).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stichwörter")
                    Text(watch.isEmpty ? "Noch keine gewählt" : watch.map(\.t).prefix(4).joined(separator: ", ") + (watch.count > 4 ? " +\(watch.count - 4)" : ""))
                        .font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                }
            }
        }
        Toggle(isOn: Binding(get: { DealsBucket.minTemp(config) >= 100 }, set: { config["min"] = .number($0 ? 100 : 0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nur heiße Deals")
                Text("Ab 100° – die Community findet sie richtig gut").font(.caption).foregroundColor(Theme.secondary)
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

/// Stichwörter verwalten: eigene eintippen, Vorschläge antippen
struct DealWatchView: View {
    @Binding var config: [String: JSON]
    @ObservedObject private var service = DealService.shared
    @State private var text = ""
    @State private var preview: DealPreview?
    @State private var loading = false

    private var watch: [DealWatch] { DealsBucket.watch(config) }
    private func save(_ w: [DealWatch]) { DealsBucket.store(w, in: &config) }
    private var query: String { text.trimmingCharacters(in: .whitespaces) }

    /// Schon gewählt? (Groß/klein egal)
    private func has(_ t: String) -> Bool { watch.contains { $0.t.caseInsensitiveCompare(t) == .orderedSame } }

    private func add(_ t: String) {
        let t = t.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2, !has(t) else { text = ""; return }
        save(watch + [DealWatch(t: t)])
        text = ""; preview = nil
    }

    private func toggle(_ t: String) {
        if has(t) { save(watch.filter { $0.t.caseInsensitiveCompare(t) != .orderedSame }) } else { add(t) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent)
                    TextField("Eigenes Stichwort, z. B. Airfryer", text: $text)
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
                        Text(p.n == 0 ? "Gerade kein passender Deal – Hubert meldet sich, sobald einer auftaucht."
                             : "\(p.n) passende \(p.n == 1 ? "Deal" : "Deals") gerade")
                            .font(.subheadline).foregroundColor(Theme.secondary)
                        ForEach(p.deals.prefix(3)) { d in DealRow(deal: d, compact: true) }
                        if !p.std.alts.isEmpty {
                            Text("Passt automatisch auch auf: " + p.std.alts.joined(separator: ", ")).font(.caption).foregroundColor(Theme.secondary)
                        }
                    }
                }
            } footer: {
                Text("Groß/klein, Umlaute, Mehrzahl und kleine Tippfehler sind egal – „kopfhoerer“ findet auch „Kopfhörer“.")
            }

            Section {
                if watch.isEmpty { Text("Noch keine – tipp unten auf Vorschläge oder gib oben eins ein.").foregroundColor(Theme.secondary) }
                ForEach(watch) { w in
                    NavigationLink(destination: DealTermEdit(config: $config, id: w.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.t)
                            Text(w.summary).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                        }
                    }
                }
                .onDelete { idx in var l = watch; l.remove(atOffsets: idx); save(l) }
                .onMove { from, to in var l = watch; l.move(fromOffsets: from, toOffset: to); save(l) }
            } header: { Text("Meine Stichwörter") } footer: {
                if !watch.isEmpty { Text("Antippen: Höchstpreis und genauere Wörter festlegen. Wischen entfernt.") }
            }

            ForEach(service.catalog) { group in
                Section(header: Text(group.emoji + "  " + group.name)) {
                    ForEach(group.items, id: \.t) { item in
                        Button { withAnimation { toggle(item.t) } } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.t).foregroundColor(.primary)
                                    if !item.alts.isEmpty {
                                        Text("auch " + item.alts.prefix(3).joined(separator: ", ")).font(.caption).foregroundColor(Theme.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: has(item.t) ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.title3).foregroundColor(has(item.t) ? Theme.accent : Color(UIColor.tertiaryLabel))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.t + (has(item.t) ? ", gewählt" : ""))
                    }
                }
            }
            if service.catalog.isEmpty {
                Section { HStack(spacing: 10) { ProgressView(); Text("Lade Vorschläge …").foregroundColor(Theme.secondary) } }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Stichwörter")
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

/// Ein Stichwort genauer einstellen
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
