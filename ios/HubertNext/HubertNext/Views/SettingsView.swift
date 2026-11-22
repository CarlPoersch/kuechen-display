import SwiftUI

// ============================================================
// Einstellungen: Startseite (Buckets sortieren, entfernen, einstellen, hinzufügen),
// Interessen, Haushalt (Code teilen), Konto.
// ============================================================
struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var look = ThemeStore.shared   // färbt sich bei Themawechsel sofort um
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var lastMember = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var householdName = ""
    @State private var copied = false
    @State private var members: Int?
    @ObservedObject private var live = LiveSync.shared

    private var version: String {
        let i = Bundle.main.infoDictionary
        return "Hubert \(i?["CFBundleShortVersionString"] as? String ?? "?") (Build \(i?["CFBundleVersion"] as? String ?? "?"))"
    }

    /// Zeile unter dem Namen: ausgeblendet / Knopf / Größe
    private func rowDetail(_ inst: BucketInstance, _ kind: BucketKind) -> String {
        if store.hiddenHere.contains(inst.id) { return "Auf diesem " + AppStore.deviceName + " ausgeblendet" }
        switch kind.art {
        case .button: return "Knopf unten rechts"
        case .tool: return inst.size.label + " · App"
        case .glance: return inst.size.label
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(store.buckets) { inst in
                        if let kind = BucketRegistry.kind(inst.bucket) {
                            NavigationLink(destination: BucketEditView(bucketId: inst.id)) {
                                BucketRow(kind: kind, detail: rowDetail(inst, kind))
                                    .opacity(store.hiddenHere.contains(inst.id) ? 0.5 : 1)
                            }
                        }
                    }
                    .onMove { store.moveBuckets(from: $0, to: $1) }
                    .onDelete { idx in idx.map { store.buckets[$0].id }.forEach { store.removeBucket(id: $0) } }
                    Button { showAdd = true } label: { Label("Bucket hinzufügen", systemImage: "plus.circle.fill") }
                } header: { Text("Startseite") } footer: { Text("Zum Sortieren oben auf „Bearbeiten“ tippen.") }

                Section("Darstellung") {
                    NavigationLink(destination: AppearanceView()) {
                        HStack(spacing: 12) {
                            Circle().fill(ThemeStore.shared.current.gradient).frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Farbthema & Kopfbereich")
                                Text(ThemeStore.shared.current.name).font(.caption).foregroundColor(Theme.secondary)
                            }
                        }
                    }
                }

                Section("Interessen") {
                    NavigationLink(destination: InterestsEditView()) {
                        Text(interestText).lineLimit(2)
                    }
                }

                if let h = store.household {
                    Section {
                        TextField("Name", text: $householdName, onCommit: { Task { await store.renameHousehold(householdName) } })
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Einladungscode").font(.caption).foregroundColor(Theme.secondary)
                                Text(h.inviteCode).font(.title2.monospaced().weight(.semibold))
                            }
                            Spacer()
                            Button(copied ? "Kopiert" : "Kopieren") {
                                UIPasteboard.general.string = h.inviteCode
                                copied = true
                            }
                            .buttonStyle(.bordered)
                        }
                        if let n = members {
                            HStack {
                                Text("Mitglieder")
                                Spacer()
                                Text(n == 1 ? "nur du" : "\(n) Personen").foregroundColor(Theme.secondary)
                            }
                        }
                        HStack(spacing: 10) {
                            Circle().fill(live.connected ? Color.green : Color(UIColor.systemGray3)).frame(width: 10, height: 10)
                            Text("Live-Abgleich")
                            Spacer()
                            Text(live.connected ? "verbunden" : "getrennt").foregroundColor(Theme.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    } header: { Text("Haushalt") } footer: {
                        Text("Mit diesem Code treten andere deinem Haushalt bei und teilen Küche, Einkaufsliste und Haushalts-Tools. Timer und das laufende Rezept erscheinen auf allen Geräten dieses Haushalts – auch auf deinen eigenen, wenn du dort mit demselben Konto angemeldet bist."
                             + (live.lastSync.map { " Zuletzt abgeglichen: " + Fmt.hhmm($0) + " Uhr." } ?? ""))
                    }
                }

                Section {
                    if let name = store.profile?.name { Text(name) }
                    Button("Abmelden", role: .destructive) { confirmSignOut = true }
                    Button(role: .destructive) {
                        Task { lastMember = await store.isLastMember(); confirmDelete = true }
                    } label: {
                        HStack { Text("Konto löschen"); if deleting { Spacer(); ProgressView() } }
                    }
                    .disabled(deleting)
                    if let e = deleteError { Text(e).font(.footnote).foregroundColor(.red) }
                } header: { Text("Konto") } footer: {
                    Text("Löschen entfernt dein Konto, deine Startseite und deine Einstellungen endgültig. Bist du das letzte Mitglied deines Haushalts, wird auch dessen Küche gelöscht.\n\n" + version)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Fertig") { dismiss() }.font(.body.weight(.semibold)) }
            }
            .sheet(isPresented: $showAdd) { AddBucketView().environmentObject(store) }
            .confirmationDialog("Wirklich abmelden?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) { store.signOut(); dismiss() }
            }
            .alert("Konto endgültig löschen?", isPresented: $confirmDelete) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    Task {
                        deleting = true; deleteError = nil
                        do { try await store.deleteAccount(); dismiss() }
                        catch { deleteError = "Löschen hat nicht geklappt: " + error.localizedDescription }
                        deleting = false
                    }
                }
            } message: {
                Text(lastMember
                     ? "Du bist das letzte Mitglied von „\(store.household?.name ?? "deinem Haushalt")“. Konto, Haushalt und die ganze Küche (Einkauf, Vorrat, Rezepte) werden gelöscht. Das lässt sich nicht rückgängig machen."
                     : "Dein Konto und deine Startseite werden gelöscht. Der Haushalt mit Küche bleibt für die anderen Mitglieder bestehen. Das lässt sich nicht rückgängig machen.")
            }
            .onAppear { householdName = store.household?.name ?? "" }
            .task { members = await store.memberCount() }
        }
        .navigationViewStyle(.stack)
    }

    private var interestText: String {
        let names = Interest.all.filter { store.profile?.interests.contains($0.id) == true }.map { $0.name }
        return names.isEmpty ? "Noch keine ausgewählt" : names.joined(separator: ", ")
    }
}

/// Zeile mit farbigem Symbol wie in den iOS-Einstellungen
struct BucketRow: View {
    let kind: BucketKind
    var detail: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(kind.tint))
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.name)
                if let d = detail { Text(d).font(.caption).foregroundColor(Theme.secondary) }
            }
        }
    }
}

// MARK: Einzelnen Bucket einstellen

struct BucketEditView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let bucketId: String

    private var index: Int? { store.buckets.firstIndex { $0.id == bucketId } }

    var body: some View {
        Form {
            if let i = index, let kind = BucketRegistry.kind(store.buckets[i].bucket) {
                if kind.art == .glance {
                    Section {
                        Picker("Größe", selection: sizeBinding(i)) {
                            ForEach(kind.sizes) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Größe auf diesem " + (UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"))
                    } footer: {
                        Text("Größe und Reihenfolge gelten nur für dieses Gerät. Inhalte und Einstellungen sind überall gleich.")
                    }
                }
                Section {
                    Toggle("Auf diesem " + AppStore.deviceName + " zeigen",
                           isOn: Binding(get: { !store.hiddenHere.contains(bucketId) }, set: { store.setHidden(bucketId, !$0) }))
                        .tint(Theme.accent)
                } footer: {
                    Text("Ausgeblendet heißt nur auf diesem Gerät – auf deinen anderen Geräten bleibt der Bucket sichtbar.")
                }
                if let settings = kind.settings {
                    Section("Einstellungen") { settings(configBinding(i)) }
                }
                Section {
                    Button("Von der Startseite entfernen", role: .destructive) {
                        store.removeBucket(id: bucketId); dismiss()
                    }
                }
            }
        }
        .navigationTitle(index.flatMap { BucketRegistry.kind(store.buckets[$0].bucket)?.name } ?? "")
        .onDisappear { store.saveBuckets() }
    }

    private func sizeBinding(_ i: Int) -> Binding<BucketSize> {
        Binding(get: { store.buckets.indices.contains(i) ? store.buckets[i].size : .m },
                set: { if store.buckets.indices.contains(i) { store.buckets[i].size = $0 } })
    }
    private func configBinding(_ i: Int) -> Binding<[String: JSON]> {
        Binding(get: { store.buckets.indices.contains(i) ? store.buckets[i].config : [:] },
                set: { if store.buckets.indices.contains(i) { store.buckets[i].config = $0 } })
    }
}

// MARK: Bucket hinzufügen (Katalog)

struct AddBucketView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(Interest.all) { interest in
                    let kinds = BucketRegistry.all.filter { $0.interests.first == interest.id }
                    if !kinds.isEmpty {
                        Section(interest.name) {
                            ForEach(kinds) { kind in
                                CatalogRow(kind: kind, count: store.buckets.filter { $0.bucket == kind.id }.count,
                                           onAdd: { store.addBucket(kind) },
                                           onRemove: {
                                               // Den zuletzt hinzugefügten dieser Art entfernen
                                               if let last = store.buckets.last(where: { $0.bucket == kind.id }) { store.removeBucket(id: last.id) }
                                           })
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bucket hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }
}

/// Eintrag im Katalog: Symbol, Name, ein Satz, Hinzufügen-Knopf oder "bald"
struct CatalogRow: View {
    let kind: BucketKind
    let count: Int            // wie oft schon auf der Startseite
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BucketRow(kind: kind, detail: kind.blurb)
            Spacer()
            if !kind.available {
                Text("bald").font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
            } else if count == 0 {
                Button(action: onAdd) { Image(systemName: "plus.circle.fill").font(.title2) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("„\(kind.name)“ hinzufügen")
            } else {
                // Schon auf der Startseite: − entfernt, + fügt einen weiteren hinzu (z. B. anderer Ort)
                Button(action: onRemove) { Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.red) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("„\(kind.name)“ entfernen")
                if kind.art != .glance {
                    Image(systemName: "checkmark").foregroundColor(Theme.accent)
                } else {
                    Text("\(count)×").font(.subheadline.monospacedDigit().weight(.semibold)).foregroundColor(Theme.secondary)
                        .frame(minWidth: 24)
                    Button(action: onAdd) { Image(systemName: "plus.circle").font(.title2) }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Weiteren „\(kind.name)“ hinzufügen")
                }
            }
        }
        .opacity(kind.available ? 1 : 0.55)
    }
}

// MARK: Interessen ändern

struct InterestsEditView: View {
    @EnvironmentObject var store: AppStore
    @State private var selected: Set<String> = []

    var body: some View {
        List(Interest.all) { i in
            Button {
                if selected.contains(i.id) { selected.remove(i.id) } else { selected.insert(i.id) }
            } label: {
                HStack {
                    Label(i.name, systemImage: i.symbol).foregroundColor(.primary)
                    Spacer()
                    if selected.contains(i.id) { Image(systemName: "checkmark").foregroundColor(Theme.accent) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Interessen")
        .onAppear { selected = Set(store.profile?.interests ?? []) }
        .onDisappear { Task { await store.saveInterests(Interest.all.map { $0.id }.filter { selected.contains($0) }) } }
    }
}
