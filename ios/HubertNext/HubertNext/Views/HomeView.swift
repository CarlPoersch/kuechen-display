import SwiftUI

// ============================================================
// Startseite: oben das Briefing (Glance-Buckets im Raster),
// darunter die Tools als App-Symbole, immer 4 pro Zeile.
// Das Raster passt sich der Breite an: iPhone 2 Spalten, iPad hoch 4, iPad quer 6.
// ============================================================
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var showSettings = false
    @State private var scrolled: CGFloat = 0   // wie weit nach unten gescrollt

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
                            .background(GeometryReader { g in
                                Color.clear.preference(key: ScrollOffsetKey.self, value: g.frame(in: .named("home")).minY)
                            })
                        BriefingGrid(items: glances, width: geo.size.width - 2 * pad(geo.size.width))
                        if glances.isEmpty {
                            emptyHint
                        }
                        toolsSection
                    }
                    .padding(.horizontal, pad(geo.size.width))
                    .padding(.vertical, 12)
                }
                .coordinateSpace(name: "home")
                .onPreferenceChange(ScrollOffsetKey.self) { y in scrolled = 12 - y }
                .refreshable { await store.reload() }
                // Große Kopfkarte weggescrollt → schmale Leiste bleibt oben stehen
                .overlay(alignment: .top) {
                    if scrolled > 120 { compactBar(pad(geo.size.width)).transition(.move(edge: .top).combined(with: .opacity)) }
                }
                .animation(.easeOut(duration: 0.2), value: scrolled > 120)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
    }

    private func pad(_ w: CGFloat) -> CGFloat { w < 600 ? 16 : 24 }

    // Kopf: orange Karte mit Begrüßung, großer Uhr und Datum; Einstellungen oben rechts
    private var header: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting(ctx.date) + (store.profile?.name.map { ", " + firstName($0) } ?? ""))
                        .font(.headline).foregroundColor(.white.opacity(0.9))
                    Text(ctx.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                        .font(.system(size: 76, weight: .thin, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(ctx.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE"))))
                        .font(.title3.weight(.medium)).foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.22)))
                }
                .accessibilityLabel("Einstellungen")
            }
            .padding(.horizontal, 22).padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.97, green: 0.64, blue: 0.36),
                                                  Color(red: 0.92, green: 0.42, blue: 0.12),
                                                  Color(red: 0.76, green: 0.25, blue: 0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: Color(red: 0.76, green: 0.25, blue: 0.05).opacity(0.25), radius: 14, y: 6)
        }
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
            .background(heroGradient.ignoresSafeArea(edges: .top))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
    }

    private var heroGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.97, green: 0.64, blue: 0.36), Color(red: 0.92, green: 0.42, blue: 0.12),
                                Color(red: 0.76, green: 0.25, blue: 0.05)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
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
                        AppIcon(kind: kind)
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

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
    let items: [BucketInstance]
    let width: CGFloat
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
                let free = width - gap * CGFloat(row.count - 1)
                HStack(alignment: .top, spacing: gap) {
                    ForEach(row) { it in
                        BucketCard(instance: it)
                            .frame(width: free * CGFloat(min(span(it.size), columns)) / total, height: height(row))
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
struct BucketCard: View {
    let instance: BucketInstance

    var body: some View {
        if let kind = BucketRegistry.kind(instance.bucket) {
            VStack(alignment: .leading, spacing: 10) {
                head(kind)
                content(kind)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
    }

    private func destination(_ kind: BucketKind) -> some View {
        (kind.detail?(instance) ?? AnyView(EmptyView())).navigationTitle(kind.name)
    }

    @ViewBuilder private func head(_ kind: BucketKind) -> some View {
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
            NavigationLink(destination: destination(kind)) { row }.buttonStyle(.plain)
        } else {
            row
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
            NavigationLink(destination: destination(kind)) { inner }.buttonStyle(.plain)
        } else {
            inner
        }
    }
}
