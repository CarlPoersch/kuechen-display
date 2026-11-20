import SwiftUI

// ============================================================
// Einstellungen: Startseite (Buckets sortieren, entfernen, einstellen, hinzufügen),
// Interessen, Haushalt (Code teilen), Konto.
// ============================================================
struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var confirmSignOut = false
    @State private var householdName = ""
    @State private var copied = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(store.buckets) { inst in
                        if let kind = BucketRegistry.kind(inst.bucket) {
                            NavigationLink(destination: BucketEditView(bucketId: inst.id)) {
                                BucketRow(kind: kind, detail: inst.size.label + (kind.art == .tool ? " · App" : ""))
                            }
                        }
                    }
                    .onMove { store.moveBuckets(from: $0, to: $1) }
                    .onDelete { idx in idx.map { store.buckets[$0].id }.forEach { store.removeBucket(id: $0) } }
                    Button { showAdd = true } label: { Label("Bucket hinzufügen", systemImage: "plus.circle.fill") }
                } header: { Text("Startseite") } footer: { Text("Zum Sortieren oben auf „Bearbeiten“ tippen.") }

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
                    } header: { Text("Haushalt") } footer: {
                        Text("Mit diesem Code treten andere deinem Haushalt bei und teilen Küche, Einkaufsliste und Haushalts-Tools.")
                    }
                }

                Section("Konto") {
                    if let name = store.profile?.name { Text(name) }
                    Button("Abmelden", role: .destructive) { confirmSignOut = true }
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
            .onAppear { householdName = store.household?.name ?? "" }
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
                    Section("Größe auf der Startseite") {
                        Picker("Größe", selection: sizeBinding(i)) {
                            ForEach(kind.sizes) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
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
                                CatalogRow(kind: kind, added: store.buckets.contains { $0.bucket == kind.id }) {
                                    store.addBucket(kind)
                                }
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
    let added: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BucketRow(kind: kind, detail: kind.blurb)
            Spacer()
            if !kind.available {
                Text("bald").font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
            } else if added && kind.art == .tool {
                Image(systemName: "checkmark").foregroundColor(Theme.accent)
            } else if added {
                // Schon auf der Startseite – ein zweiter (z. B. anderer Ort) geht trotzdem
                Image(systemName: "checkmark").foregroundColor(Theme.accent)
                Button(action: onAdd) { Image(systemName: "plus.circle").font(.title2) }
                    .buttonStyle(.borderless)
            } else {
                Button(action: onAdd) { Image(systemName: "plus.circle.fill").font(.title2) }
                    .buttonStyle(.borderless)
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
