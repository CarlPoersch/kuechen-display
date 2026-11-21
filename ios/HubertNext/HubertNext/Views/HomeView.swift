import SwiftUI
import UniformTypeIdentifiers

// ============================================================
// Startseite: oben das Briefing (Glance-Buckets im Raster),
// darunter die Tools als App-Symbole, immer 4 pro Zeile.
// Das Raster passt sich der Breite an: iPhone 2 Spalten, iPad hoch 4, iPad quer 6.
// ============================================================
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var showSettings = false
    @State private var collapsed = false        // große Kopfkarte weggescrollt → schmale Leiste
    @State private var editing = false          // Startseite bearbeiten (wackeln, verschieben)
    @State private var dragging: String?        // Bucket, der gerade gezogen wird
    @ObservedObject private var look = ThemeStore.shared

    private var glances: [BucketInstance] {
        store.buckets.filter { BucketRegistry.kind($0.bucket)?.art == .glance }
    }
    private var tools: [BucketInstance] {
        store.buckets.filter { BucketRegistry.kind($0.bucket)?.art == .tool }
    }

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        BriefingGrid(items: glances, width: geo.size.width - 2 * pad(geo.size.width), dragging: $dragging)
                        if glances.isEmpty {
                            emptyHint
                        }
                        toolsSection
                    }
                    // Neues Farbthema → alle Karten neu zeichnen (sie lesen die Akzentfarbe beim Zeichnen)
                    .id(look.refreshKey)
                    .padding(.horizontal, pad(geo.size.width))
                    .padding(.vertical, 12)
                    // Liest die Scroll-Position direkt aus UIKit (die SwiftUI-Messung
                    // hat auf dem iPad mit iOS 15 nicht zuverlässig ausgelöst)
                    .background(ScrollOffsetReader { y in
                        let c = y > (look.compactHeader ? 95 : 130)
                        if c != collapsed { collapsed = c }
                    })
                }
                .refreshable { await store.reload() }
                // Große Kopfkarte weggescrollt → schmale Leiste bleibt oben stehen
                .overlay(alignment: .top) {
                    if editing { editBar(pad(geo.size.width)).transition(.move(edge: .top).combined(with: .opacity)) }
                    else if collapsed { compactBar(pad(geo.size.width)).transition(.move(edge: .top).combined(with: .opacity)) }
                }
                .animation(.easeOut(duration: 0.2), value: collapsed)
                .animation(.easeOut(duration: 0.2), value: editing)
                .environment(\.homeEditing, editing)
                .environment(\.startHomeEditing, { withAnimation { editing = true } })
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
    }

    private func pad(_ w: CGFloat) -> CGFloat { w < 600 ? 16 : 24 }

    // Kopf: farbige Karte (Thema aus Einstellungen → Darstellung)
    private var header: some View {
        HeroHeader(name: store.profile?.name.map { firstName($0) }, onSettings: { showSettings = true })
    }

    /// Leiste im Bearbeiten-Modus, wie auf dem iPhone-Home-Bildschirm
    private func editBar(_ pad: CGFloat) -> some View {
        HStack {
            Button { showSettings = true } label: { Label("Hinzufügen", systemImage: "plus") }
            Spacer()
            Text("Ziehen zum Verschieben").font(.subheadline).foregroundColor(Theme.secondary)
            Spacer()
            Button { withAnimation { editing = false }; store.saveBuckets() } label: {
                Text("Fertig").font(.body.weight(.semibold)).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.accent))
            }
        }
        .padding(.horizontal, pad + 4).padding(.vertical, 10)
        .background(Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top))
    }

    /// Schmale Leiste: Uhr, Datum, Einstellungen
    private func compactBar(_ pad: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            HStack(spacing: 12) {
                Text(ctx.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: 24, weight: .semibold)).monospacedDigit()
                Text(ctx.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "de_DE"))))
                    .font(.subheadline.weight(.medium)).opacity(0.9)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.22)))
                }
                .accessibilityLabel("Einstellungen")
            }
            .foregroundColor(.white)
            .padding(.horizontal, pad + 6).padding(.vertical, 10)
            .background(look.current.gradient.ignoresSafeArea(edges: .top))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
    }

    private var emptyHint: some View {
        Button { showSettings = true } label: {
            Label("Buckets hinzufügen", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity).padding()
                .background(RoundedRectangle(cornerRadius: Theme.cardRadius).fill(Theme.card))
        }
    }

    @ViewBuilder private var toolsSection: some View {
        if !tools.isEmpty {
            Text("APPS").font(.footnote.weight(.semibold)).foregroundColor(Theme.secondary).padding(.top, 6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 18) {
                ForEach(tools) { inst in
                    if let kind = BucketRegistry.kind(inst.bucket) {
                        ToolIcon(instance: inst, kind: kind)
                            .disabled(editing)
                            .overlay(alignment: .topLeading) {
                                if editing { RemoveBadge { store.removeBucket(id: inst.id) }.offset(x: 2, y: -6) }
                            }
                            .modifier(Wiggle(on: editing))
                            .contextMenu(editing ? nil : ContextMenu {
                                Button { withAnimation { editing = true } } label: { Label("Startseite bearbeiten", systemImage: "square.grid.2x2") }
                                Button(role: .destructive) { store.removeBucket(id: inst.id) } label: { Label("Entfernen", systemImage: "trash") }
                            })
                            .onDrag { dragging = inst.id; withAnimation { editing = true }; return NSItemProvider(object: inst.id as NSString) }
                            .onDrop(of: [UTType.text], delegate: BucketDrop(target: inst.id, dragging: $dragging, store: store))
                    }
                }
            }
        }
    }

    private func greeting(_ d: Date) -> String {
        let h = Calendar.current.component(.hour, from: d)
        return h < 5 ? "Gute Nacht" : h < 11 ? "Guten Morgen" : h < 18 ? "Guten Tag" : "Guten Abend"
    }
    private func firstName(_ n: String) -> String { n.split(separator: " ").first.map(String.init) ?? n }
}

/// Meldet, wie weit die umgebende Scrollfläche gescrollt ist (0 = ganz oben).
/// Sucht dazu die echte UIScrollView und beobachtet deren Position.
struct ScrollOffsetReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> Reader { let v = Reader(); v.onChange = onChange; return v }
    func updateUIView(_ v: Reader, context: Context) { v.onChange = onChange }

    final class Reader: UIView {
        var onChange: ((CGFloat) -> Void)?
        private var observation: NSKeyValueObservation?

        override func didMoveToWindow() { super.didMoveToWindow(); attach() }
        override func layoutSubviews() { super.layoutSubviews(); attach() }

        private func attach() {
            guard observation == nil, window != nil else { return }
            var v = superview
            while let s = v, !(s is UIScrollView) { v = s.superview }
            guard let scroll = v as? UIScrollView else { return }
            observation = scroll.observe(\.contentOffset, options: [.initial, .new]) { [weak self] sv, _ in
                let y = sv.contentOffset.y + sv.adjustedContentInset.top
                DispatchQueue.main.async { self?.onChange?(y) }
            }
        }
    }
}

/// App-Symbol, das seine App öffnet (unsichtbarer Link, per Knopf ausgelöst – wie bei den Karten)
struct ToolIcon: View {
    let instance: BucketInstance
    let kind: BucketKind
    @State private var open = false
    var body: some View {
        Button { if kind.detail != nil { open = true } } label: { AppIcon(kind: kind) }
            .buttonStyle(.plain)
            .background(
                NavigationLink(isActive: $open) { BucketDetailHost(instance: instance, kind: kind) } label: { EmptyView() }
                    .frame(width: 0, height: 0).allowsHitTesting(false).hidden()
            )
    }
}

/// App-Symbol im Stil des Home-Bildschirms
struct AppIcon: View {
    let kind: BucketKind
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: kind.symbol)
                .font(.system(size: 30, weight: .medium)).foregroundColor(.white)
                .frame(width: 68, height: 68)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [kind.tint.opacity(0.85), kind.tint], startPoint: .top, endPoint: .bottom)))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            Text(kind.name).font(.caption).lineLimit(1)
        }
    }
}

// MARK: Briefing-Raster

/// Ordnet Buckets in Reihen: Klein = 1 Einheit, Mittel = 2, Groß = ganze Breite.
/// Warum eigenes Raster: SwiftUI auf iOS 15 kann Kacheln nicht über mehrere Spalten spannen.
struct BriefingGrid: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.homeEditing) private var editing
    @Environment(\.startHomeEditing) private var startEditing
    let items: [BucketInstance]
    let width: CGFloat
    @Binding var dragging: String?
    private let gap: CGFloat = 14

    private var columns: Int { width < 560 ? 2 : (width < 1000 ? 4 : 6) }

    private func span(_ s: BucketSize) -> Int {
        switch s {
        case .s: return columns == 6 ? 2 : 1
        case .m: return columns == 6 ? 3 : 2
        case .l: return columns
        }
    }

    private var rows: [[BucketInstance]] {
        var out: [[BucketInstance]] = []; var cur: [BucketInstance] = []; var used = 0
        for it in items {
            let sp = min(span(it.size), columns)
            if used + sp > columns, !cur.isEmpty { out.append(cur); cur = []; used = 0 }
            cur.append(it); used += sp
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                // Füllt eine Reihe nicht die ganze Breite, werden ihre Karten anteilig breiter.
                // Warum: Jede Reihe endet bündig rechts → das Briefing bleibt ein Rechteck.
                let total = CGFloat(row.reduce(0) { $0 + min(span($1.size), columns) })
                let free = max(0, width - gap * CGFloat(row.count - 1))   // beim ersten Messen kann die Breite 0 sein
                HStack(alignment: .top, spacing: gap) {
                    ForEach(row) { it in
                        BucketCard(instance: it)
                            .frame(width: free * CGFloat(min(span(it.size), columns)) / total, height: height(row))
                            .opacity(dragging == it.id ? 0.4 : 1)
                            // Im Bearbeiten-Modus: Karte ziehen und auf einer anderen loslassen
                            .onDrag { dragging = it.id; startEditing(); return NSItemProvider(object: it.id as NSString) }
                            .onDrop(of: [UTType.text], delegate: BucketDrop(target: it.id, dragging: $dragging, store: store))
                    }
                }
            }
        }
    }

    /// Alle Karten einer Reihe gleich hoch → saubere Rechtecke
    private func height(_ row: [BucketInstance]) -> CGFloat {
        // Groß: bis zu 6 Einträge · Mittel: 3 · Klein: einer
        row.contains { $0.size == .l } ? 340 : row.contains { $0.size == .m } ? 240 : 170
    }
}

/// Karte mit Kopfzeile. Der Kopf ("Alle ›") öffnet die Details.
/// Der Inhalt öffnet sie auch – außer der Bucket hat eigene antippbare Einträge.
/// Der Regler-Knopf (oder lange drücken) öffnet die Einstellungen direkt hier.
struct BucketCard: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.homeEditing) private var homeEditing
    @Environment(\.startHomeEditing) private var startHomeEditing
    let instance: BucketInstance
    @State private var editing = false
    @State private var open = false   // Details geöffnet

    var body: some View {
        if let kind = BucketRegistry.kind(instance.bucket) {
            VStack(alignment: .leading, spacing: 10) {
                head(kind)
                content(kind)
            }
            .disabled(homeEditing)   // beim Bearbeiten nichts öffnen
            // Unsichtbarer Link, nur per Knopf ausgelöst. Warum: Ein sichtbarer Link um die Karte
            // fängt auf iOS 15 auch Tipper auf Menüs darin ab (ÖPNV-Auswahl öffnete die Details).
            .background(
                NavigationLink(isActive: $open) { BucketDetailHost(instance: instance, kind: kind) } label: { EmptyView() }
                    .frame(width: 0, height: 0)      // ohne Fläche: kein Tipper kann ihn treffen
                    .allowsHitTesting(false)
                    .hidden()
            )
            .environment(\.bucketId, instance.id)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            .overlay(alignment: .topLeading) {
                if homeEditing { RemoveBadge { store.removeBucket(id: instance.id) }.offset(x: -8, y: -8) }
            }
            .modifier(Wiggle(on: homeEditing))
            .contextMenu(homeEditing ? nil : ContextMenu {
                Button { editing = true } label: { Label("Anpassen", systemImage: "slider.horizontal.3") }
                Button { startHomeEditing() } label: { Label("Startseite bearbeiten", systemImage: "square.grid.2x2") }
                Button(role: .destructive) { store.removeBucket(id: instance.id) } label: { Label("Entfernen", systemImage: "trash") }
            })
            .environment(\.editBucket, { editing = true })
            .environment(\.openBucketDetail, { open = true })
            .sheet(isPresented: $editing) { BucketEditSheet(bucketId: instance.id).environmentObject(store) }
        }
    }

    @ViewBuilder private func head(_ kind: BucketKind) -> some View {
        HStack(spacing: 10) {
            let row = HStack(spacing: 6) {
                Image(systemName: kind.symbol).foregroundColor(kind.tint)
                Text(kind.name.uppercased()).font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
                Spacer(minLength: 0)
                if kind.detail != nil {
                    Text("Alle").font(.subheadline).foregroundColor(Theme.accent)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(Theme.accent)
                }
            }
            .contentShape(Rectangle())
            if kind.detail != nil {
                Button { open = true } label: { row }.buttonStyle(.plain)
            } else {
                row
            }
            if kind.settings != nil {
                Button { editing = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.subheadline.weight(.semibold)).foregroundColor(Theme.secondary)
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Anpassen")
            }
        }
    }

    @ViewBuilder private func content(_ kind: BucketKind) -> some View {
        let inner = GeometryReader { g in
            kind.glance(instance, instance.size)
                .environment(\.glanceSpace, g.size)
                .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
        .clipped()
        .contentShape(Rectangle())
        if kind.detail != nil && !kind.itemLinks {
            Button { open = true } label: { inner }.buttonStyle(.plain)
        } else {
            inner
        }
    }
}

/// Detailansicht mit "Anpassen"-Knopf oben rechts
struct BucketDetailHost: View {
    @EnvironmentObject var store: AppStore
    let instance: BucketInstance
    let kind: BucketKind
    @State private var editing = false

    /// Immer die aktuelle Fassung (nach dem Anpassen sofort sichtbar)
    private var current: BucketInstance { store.buckets.first { $0.id == instance.id } ?? instance }

    var body: some View {
        (kind.detail?(current) ?? AnyView(EmptyView()))
            .navigationTitle(kind.name)
            .navigationBarHidden(false)
            .environment(\.bucketId, instance.id)
            .environment(\.editBucket, { editing = true })
            .toolbar {
                // Warum das "if" innen steht: Bedingte Toolbar-Einträge gibt es erst ab iOS 16
                ToolbarItem(placement: .navigationBarTrailing) {
                    if kind.settings != nil {
                        Button { editing = true } label: { Image(systemName: "slider.horizontal.3") }
                            .accessibilityLabel("Anpassen")
                    }
                }
            }
            .sheet(isPresented: $editing) { BucketEditSheet(bucketId: instance.id).environmentObject(store) }
    }
}

/// Bucket-Einstellungen als Blatt mit "Fertig"
struct BucketEditSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let bucketId: String
    var body: some View {
        NavigationView {
            BucketEditView(bucketId: bucketId)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: Startseite bearbeiten

/// Leichtes Wackeln wie beim iPhone-Home-Bildschirm
struct Wiggle: ViewModifier {
    let on: Bool
    @State private var phase = false
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(on ? (phase ? 0.8 : -0.8) : 0))
            .animation(on ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true) : .easeOut(duration: 0.1), value: phase)
            .onAppear { if on { phase = true } }
            .onChange(of: on) { v in phase = v }
    }
}

/// Graues Minus oben links zum Entfernen
struct RemoveBadge: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "minus").font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.regularMaterial))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Entfernen")
    }
}

/// Beim Darüberziehen rückt der gezogene Bucket an diese Stelle
struct BucketDrop: DropDelegate {
    let target: String
    @Binding var dragging: String?
    let store: AppStore

    func dropEntered(info: DropInfo) {
        guard let id = dragging, id != target else { return }
        withAnimation(.easeInOut(duration: 0.2)) { store.moveBucket(id, to: target) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        store.saveBuckets()
        return true
    }
}
