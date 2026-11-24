import SwiftUI
import UIKit

// ============================================================
// Blättern in Karten: Einträge werden in Seiten geteilt (so viele Zeilen,
// wie in die Karte passen). Gibt es mehr, ragt die nächste Seite rechts
// ein Stück herein, darunter Seitenpunkte.
//
// Warum eine echte UIKit-Scrollfläche mit Seiten-Einrasten: iOS trennt dann
// waagerechtes Wischen (Karte) und senkrechtes (Startseite) selbst sauber –
// wie bei den waagerechten Reihen im App Store.
// ============================================================

enum Pages {
    /// Platz für die Seitenpunkte unter den Seiten
    static let dots: CGFloat = 16

    /// Einträge in Seiten teilen. Passt alles auf eine Seite, gibt es keine Punkte.
    static func split<T>(_ items: [T], height: CGFloat, row: CGFloat, maxPages: Int = 8) -> [[T]] {
        guard !items.isEmpty else { return [] }
        if items.count <= fitRows(height, row: row, max: 99) { return [items] }
        let per = fitRows(height - dots, row: row, max: 99)
        return stride(from: 0, to: min(items.count, per * maxPages), by: per)
            .map { Array(items[$0..<min($0 + per, items.count)]) }
    }

    /// Seiten nach Höhe füllen (Einträge mit unterschiedlicher Höhe, z. B. Termine mit Tagesüberschrift)
    static func split<T>(_ items: [T], height: CGFloat, maxPages: Int = 8, heightOf: (_ item: T, _ firstOnPage: Bool, _ previous: T?) -> CGFloat) -> [[T]] {
        guard !items.isEmpty else { return [] }
        func fill(_ limit: CGFloat) -> [[T]] {
            var pages: [[T]] = [[]]; var used: CGFloat = 0
            for (i, it) in items.enumerated() {
                let first = pages[pages.count - 1].isEmpty
                let h = heightOf(it, first, i > 0 ? items[i - 1] : nil)
                if !first && used + h > limit + 4 {
                    if pages.count == maxPages { break }
                    pages.append([]); used = heightOf(it, true, i > 0 ? items[i - 1] : nil)
                } else { used += h }
                pages[pages.count - 1].append(it)
            }
            return pages
        }
        let one = fill(height)
        return one.count == 1 ? one : fill(height - dots)
    }
}

struct GlancePager<Item, Page: View>: View {
    let pages: [[Item]]
    @ViewBuilder let page: ([Item]) -> Page
    @Environment(\.glanceSpace) private var space
    @State private var index = 0
    @State private var width: CGFloat = 0        // gemessene Breite
    @State private var pageHeight: CGFloat = 0   // Höhe der höchsten Seite

    private let gap: CGFloat = 14
    private let peek: CGFloat = 26

    // Warum kein GeometryReader drumherum: Die Karten sind nur so hoch wie ihr Inhalt
    // (fixedSize). Ein GeometryReader hat dabei keine eigene Höhe und fällt auf ~10 pt zusammen –
    // Inhalt verschwand (ÖPNV, Sport, News) oder lag übereinander (Vorrat). Jetzt hat der Pager
    // eine echte Höhe: die der höchsten Seite + Punkte.
    var body: some View {
        if pages.count <= 1 {
            page(pages.first ?? [])
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            let full = width > 0 ? width : space.width
            let pageWidth = max(40, full - peek - gap)
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(pages.indices, id: \.self) { i in
                            page(pages[i])
                                .frame(width: pageWidth, alignment: .topLeading)
                                .opacity(i == index ? 1 : 0.4)
                                .animation(.easeOut(duration: 0.2), value: index)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)   // eigene Höhe, egal was angeboten wird
                    .background(GeometryReader { g in
                        Color.clear.preference(key: PagerHeightKey.self, value: g.size.height)
                    })
                    .padding(.trailing, gap)   // damit die letzte Seite sauber einrastet
                    .background(PagingHelper { index = $0 })
                }
                // Die Scrollfläche ist genau eine Seite breit (+ Abstand) → Einrasten pro Seite.
                // Rechts daneben bleibt Platz, in dem die nächste Seite hereinragt.
                .frame(width: pageWidth + gap, height: pageHeight, alignment: .topLeading)
                // Die hereinragende nächste Seite rechts weich ausblenden – sonst stehen dort
                // halbe Wörter („Butt…“, „Cou…“) neben der Liste.
                .frame(width: full, alignment: .leading)
                .overlay(alignment: .trailing) {
                    LinearGradient(colors: [Theme.card.opacity(0), Theme.card], startPoint: .leading, endPoint: .trailing)
                        .frame(width: peek + gap)
                        .allowsHitTesting(false)
                }
                .clipped()

                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle().fill(i == index ? Theme.accent : Color(UIColor.tertiaryLabel))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: pageWidth)
                .frame(height: Pages.dots - 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Seite \(index + 1) von \(pages.count), waagerecht wischen für mehr")
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(GeometryReader { g in
                Color.clear.preference(key: PagerWidthKey.self, value: g.size.width)
            })
            .onPreferenceChange(PagerWidthKey.self) { w in if abs(w - width) > 0.5 { width = w } }
            .onPreferenceChange(PagerHeightKey.self) { h in if abs(h - pageHeight) > 0.5 { pageHeight = h } }
        }
    }
}

private struct PagerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct PagerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Stellt die umgebende UIKit-Scrollfläche auf Seiten-Einrasten um, lässt die
/// nächste Seite sichtbar herausragen und meldet die aktuelle Seite.
private struct PagingHelper: UIViewRepresentable {
    let onPage: (Int) -> Void

    func makeUIView(context: Context) -> Helper { let v = Helper(); v.onPage = onPage; return v }
    func updateUIView(_ v: Helper, context: Context) { v.onPage = onPage }

    final class Helper: UIView {
        var onPage: ((Int) -> Void)?
        private var observation: NSKeyValueObservation?
        private var last = -1

        override func didMoveToWindow() { super.didMoveToWindow(); attach() }
        override func layoutSubviews() { super.layoutSubviews(); attach() }

        private func attach() {
            guard observation == nil, window != nil else { return }
            var v = superview
            while let s = v, !(s is UIScrollView) { v = s.superview }
            guard let scroll = v as? UIScrollView else { return }
            scroll.isPagingEnabled = true
            scroll.clipsToBounds = false          // nächste Seite ragt rechts heraus
            scroll.alwaysBounceVertical = false
            scroll.decelerationRate = .fast
            observation = scroll.observe(\.contentOffset, options: [.new]) { @Sendable [weak self] sv, _ in
                let w = sv.bounds.width
                guard w > 0 else { return }
                let page = Int((sv.contentOffset.x / w).rounded())
                Task { @MainActor [weak self] in
                    guard let self = self, page != self.last else { return }
                    self.last = page
                    self.onPage?(page)
                }
            }
        }
    }
}
