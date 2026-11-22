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
    @State private var index = 0

    private let gap: CGFloat = 14
    private let peek: CGFloat = 26

    var body: some View {
        if pages.count <= 1 {
            page(pages.first ?? [])
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            GeometryReader { g in
                let pageWidth = max(40, g.size.width - peek - gap)
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
                        .padding(.trailing, gap)   // damit die letzte Seite sauber einrastet
                        .background(PagingHelper { index = $0 })
                    }
                    // Die Scrollfläche ist genau eine Seite breit (+ Abstand) → Einrasten pro Seite.
                    // Rechts daneben bleibt Platz, in dem die nächste Seite hereinragt.
                    .frame(width: pageWidth + gap, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .top)

                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { i in
                            Circle().fill(i == index ? Theme.accent : Color(UIColor.tertiaryLabel))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: pageWidth)
                    .frame(height: Pages.dots - 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Seite \(index + 1) von \(pages.count), waagerecht wischen für mehr")
                }
            }
        }
    }
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
