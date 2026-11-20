import SwiftUI

// ============================================================
// News-Bucket: Tagesschau (Deutschland, Welt) und heise (KI).
// Einstellungen: topics = ["de", "welt", "ki"]
// Artikel werden in Hubert selbst gelesen (kein Safari, wichtig
// im geführten Zugriff).
// ============================================================
enum NewsBucket {
    static let topics: [(id: String, name: String)] = [("de", "Deutschland"), ("welt", "Welt"), ("ki", "KI")]

    static let kind = BucketKind(
        id: "news", name: "News", symbol: "newspaper", tint: .indigo, art: .glance,
        interests: ["news", "technik"], blurb: "Top-Meldungen nach deinen Themen.",
        defaultConfig: ["topics": .array(topics.map { .string($0.id) })],
        glance: { inst, size in AnyView(NewsGlance(topics: chosen(inst.config), size: size)) },
        detail: { inst in AnyView(NewsDetail(topics: chosen(inst.config))) },
        settings: { binding in AnyView(NewsSettings(config: binding)) }
    )

    static func chosen(_ config: [String: JSON]) -> [String] {
        let list = (config["topics"]?.array ?? []).compactMap { $0.string }
        return list.isEmpty ? topics.map { $0.id } : topics.map { $0.id }.filter { list.contains($0) }
    }

    static func name(_ id: String) -> String { topics.first { $0.id == id }?.name ?? id }
}

struct NewsGlance: View {
    let topics: [String]
    let size: BucketSize
    @ObservedObject private var feed = FeedService.shared

    /// Abwechselnd aus jedem Thema die Top-Meldung, damit jedes Thema vorkommt
    private func pick(_ n: NewsFeed, count: Int) -> [(topic: String, item: NewsItem)] {
        var out: [(topic: String, item: NewsItem)] = []; var i = 0
        let lists = topics.map { t in (t, n.list(t)) }
        while out.count < count && i < 15 {
            for (t, l) in lists where i < l.count && out.count < count {
                if !out.contains(where: { $0.item.u == l[i].u }) { out.append((topic: t, item: l[i])) }
            }
            i += 1
        }
        return out
    }

    var body: some View {
        content.refreshing(every: { 300 }) { await FeedService.shared.loadNews() }
    }

    @ViewBuilder private var content: some View {
        if let n = feed.news {
            let breaking = n.breaking.first
            let count = (size == .s ? 1 : size == .m ? 3 : 6) - (breaking == nil ? 0 : 1)
            VStack(alignment: .leading, spacing: 9) {
                if let b = breaking {
                    HStack(alignment: .top, spacing: 8) {
                        Text("EIL").font(.caption2.weight(.heavy)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                        Text(b.t).font(.subheadline.weight(.semibold)).lineLimit(2)
                    }
                }
                ForEach(pick(n, count: max(1, count)), id: \.item.u) { topic, item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text((NewsBucket.name(topic) + " · " + Fmt.ago(item.date)).uppercased())
                            .font(.caption2.weight(.semibold)).foregroundColor(Theme.secondary)
                        Text(item.t).font(size == .s ? .headline : .subheadline).lineLimit(2)
                    }
                }
            }
        } else {
            Text("Lädt …").foregroundColor(Theme.secondary)
        }
    }
}

struct NewsDetail: View {
    let topics: [String]
    @State private var topic = ""
    @ObservedObject private var feed = FeedService.shared

    var body: some View {
        List {
            if topics.count > 1 {
                Picker("Thema", selection: $topic) {
                    ForEach(topics, id: \.self) { Text(NewsBucket.name($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if let n = feed.news {
                if !n.breaking.isEmpty {
                    Section(header: Text("Eilmeldung")) {
                        ForEach(n.breaking) { NewsRow(item: $0, red: true) }
                    }
                }
                Section {
                    ForEach(n.list(topic)) { NewsRow(item: $0) }
                }
            } else {
                ProgressView()
            }
        }
        .listStyle(.insetGrouped)
        .onAppear { if topic.isEmpty { topic = topics.first ?? "de" } }
        .task { await feed.loadNews() }
    }
}

struct NewsRow: View {
    let item: NewsItem
    var red = false
    var body: some View {
        NavigationLink(destination: ArticleView(item: item)) {
            VStack(alignment: .leading, spacing: 3) {
                Text(([item.top].compactMap { $0 } + [Fmt.ago(item.date)]).joined(separator: " · ").uppercased())
                    .font(.caption2.weight(.semibold)).foregroundColor(red ? .red : Theme.secondary)
                Text(item.t).font(.headline)
                if let s = item.s { Text(s).font(.subheadline).foregroundColor(Theme.secondary).lineLimit(3) }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ArticleView: View {
    let item: NewsItem
    @State private var article: Article?
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let top = article?.top ?? item.top, !top.isEmpty {
                    Text(top.uppercased()).font(.footnote.weight(.semibold)).foregroundColor(Theme.accent)
                }
                Text(article?.t ?? item.t).font(.title.weight(.bold))
                Text([article?.src, Fmt.ago(item.date)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundColor(Theme.secondary)
                if let s = article?.img, let url = URL(string: s) {
                    AsyncImage(url: url) { img in img.resizable().aspectRatio(contentMode: .fit) } placeholder: {
                        Rectangle().fill(Theme.secondary.opacity(0.12)).aspectRatio(16 / 9, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if let a = article {
                    if a.plus == true { Text("heise+ – nur der Anfang ist frei lesbar.").font(.footnote).foregroundColor(Theme.secondary) }
                    ForEach(Array(a.blocks.enumerated()), id: \.offset) { _, b in
                        switch b.k {
                        case "h": Text(b.t).font(.title3.weight(.semibold)).padding(.top, 6)
                        case "q": Text("„" + b.t + "“").font(.body.italic()).foregroundColor(Theme.secondary)
                                    .padding(.leading, 12)
                                    .overlay(Rectangle().fill(Theme.accent).frame(width: 3), alignment: .leading)
                        default: Text(b.t).font(.system(size: 19)).lineSpacing(4)
                        }
                    }
                } else if failed {
                    if let s = item.s { Text(s).font(.system(size: 19)) }
                    Text("Der ganze Artikel konnte gerade nicht geladen werden.").foregroundColor(Theme.secondary)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                }
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.card.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { article = try await FeedService.shared.article(item.key) } catch { failed = true }
        }
    }
}

struct NewsSettings: View {
    @Binding var config: [String: JSON]
    var body: some View {
        ForEach(NewsBucket.topics, id: \.id) { t in
            Toggle(t.name, isOn: $config.member("topics", t.id))
        }
    }
}

extension Binding where Value == [String: JSON] {
    /// Schalter: steht der Wert in der Liste unter key?
    func member(_ key: String, _ value: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { (wrappedValue[key]?.array ?? []).contains { $0.string == value } },
            set: { on in
                var list = (wrappedValue[key]?.array ?? []).compactMap { $0.string }.filter { $0 != value }
                if on { list.append(value) }
                wrappedValue[key] = .array(list.map { .string($0) })
            })
    }

    /// Schalter auf einen Ja/Nein-Wert (fehlt er, gilt fallback)
    func flag(_ key: String, _ fallback: Bool = true) -> Binding<Bool> {
        Binding<Bool>(get: { wrappedValue[key]?.bool ?? fallback }, set: { wrappedValue[key] = .bool($0) })
    }
}
