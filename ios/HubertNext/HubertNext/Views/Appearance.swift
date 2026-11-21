import SwiftUI

// ============================================================
// Kopfkarte der Startseite (im gewählten Thema) und die
// Einstellungsseite "Darstellung" mit Live-Vorschau.
// ============================================================

/// Die große farbige Karte oben: Begrüßung, Uhr, Datum, Zahnrad
struct HeroHeader: View {
    var name: String?
    var onSettings: (() -> Void)?
    @ObservedObject private var look = ThemeStore.shared

    var body: some View {
        let t = look.current
        let compact = look.compactHeader
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    if look.showGreeting {
                        Text(Self.greeting(ctx.date) + (name.map { ", " + $0 } ?? ""))
                            .font(compact ? .subheadline.weight(.semibold) : .headline).foregroundColor(.white.opacity(0.9))
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 14) {
                        Text(ctx.date, format: look.showSeconds
                             ? .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)
                             : .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                            .font(.system(size: compact ? 46 : 76, weight: .thin))
                            .monospacedDigit().foregroundColor(.white)
                            .minimumScaleFactor(0.6).lineLimit(1)
                        // Kompakt: Datum neben der Uhr statt darunter
                        if compact && look.showDate { dateText(ctx.date).font(.headline.weight(.medium)) }
                    }
                    if !compact && look.showDate { dateText(ctx.date).font(.title3.weight(.medium)) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let open = onSettings {
                    Button(action: open) {
                        Image(systemName: "gearshape.fill").font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.white.opacity(0.22)))
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .padding(.horizontal, 22).padding(.vertical, compact ? 14 : 20)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(t.gradient))
            .shadow(color: t.shadow, radius: 14, y: 6)
        }
    }

    private func dateText(_ d: Date) -> some View {
        Text(d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE"))))
            .foregroundColor(.white.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.8)
    }

    static func greeting(_ d: Date) -> String {
        let h = Calendar.current.component(.hour, from: d)
        return h < 5 ? "Gute Nacht" : h < 11 ? "Guten Morgen" : h < 18 ? "Guten Tag" : "Guten Abend"
    }
}

/// Einstellungen → Darstellung
struct AppearanceView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var look = ThemeStore.shared

    var body: some View {
        List {
            Section {
                HeroHeader(name: store.profile?.name?.split(separator: " ").first.map(String.init))
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            } header: { Text("Vorschau") }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 14) {
                    ForEach(HubertTheme.all) { t in swatch(t) }
                    // Eigene Farbe
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center))
                                .frame(width: 48, height: 48)
                            ColorPicker("", selection: $look.customColor, supportsOpacity: false)
                                .labelsHidden().opacity(0.02).frame(width: 48, height: 48)
                            if look.themeId == "eigene" { selectedRing }
                        }
                        Text("Eigene").font(.caption)
                    }
                }
                .padding(.vertical, 6)
            } header: { Text("Farbthema") } footer: {
                Text("Färbt die Kopfkarte, die schmale Leiste beim Scrollen, Zurück-Knöpfe und alle Akzente. Gilt für dieses Gerät.")
            }

            Section {
                Picker("Größe", selection: $look.compactHeader) {
                    Text("Groß").tag(false)
                    Text("Kompakt").tag(true)
                }
                .pickerStyle(.segmented)
                Toggle("Begrüßung", isOn: $look.showGreeting)
                Toggle("Datum", isOn: $look.showDate)
                Toggle("Sekunden", isOn: $look.showSeconds)
            } header: { Text("Kopfbereich") } footer: {
                Text("Kompakt spart Platz für mehr Buckets – praktisch auf dem iPhone.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Darstellung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func swatch(_ t: HubertTheme) -> some View {
        Button { withAnimation { look.themeId = t.id } } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(t.gradient).frame(width: 48, height: 48)
                    if look.themeId == t.id { selectedRing }
                }
                Text(t.name).font(.caption).foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thema \(t.name)" + (look.themeId == t.id ? ", ausgewählt" : ""))
    }

    private var selectedRing: some View {
        ZStack {
            Circle().stroke(Color.primary, lineWidth: 2.5).frame(width: 56, height: 56)
            Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
        }
    }
}
