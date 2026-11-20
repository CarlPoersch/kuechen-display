import SwiftUI
import AuthenticationServices
import CryptoKit

// ============================================================
// Erster Start: Anmelden → Haushalt → Interessen → Buckets → Einstellungen → Fertig.
// Ziel: in unter 2 Minuten eine persönliche Startseite.
// ============================================================
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore

    enum Step: Equatable { case welcome, household, interests, buckets, setup(Int), done }
    @State private var step: Step = .welcome
    @State private var interests: Set<String> = []
    @State private var chosen: [BucketInstance] = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: syncStep)
        .onChange(of: store.phase) { _ in syncStep() }
        .alert("Hoppla", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    /// Nach der Anmeldung dort weitermachen, wo es sinnvoll ist
    private func syncStep() {
        guard store.phase == .onboarding else { step = .welcome; return }
        if step == .welcome { step = store.household == nil ? .household : .interests }
        if interests.isEmpty { interests = Set(store.profile?.interests ?? []) }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: WelcomeStep(busy: $busy, error: $error)
        case .household: HouseholdStep(busy: $busy, error: $error) { step = .interests }
        case .interests:
            InterestsStep(selected: $interests) {
                Task { await store.saveInterests(Interest.all.map { $0.id }.filter { interests.contains($0) }) }
                chosen = suggested()
                step = .buckets
            }
        case .buckets:
            BucketPickStep(interests: interests, chosen: $chosen) { nextSetup(after: -1) }
        case .setup(let i):
            SetupStep(instance: $chosen[i]) { nextSetup(after: i) }
        case .done:
            DoneStep(busy: busy) { finish() }
        }
    }

    /// Vorschlag: verfügbare Buckets, die zu den Interessen passen (Wetter und Countdowns immer)
    private func suggested() -> [BucketInstance] {
        BucketRegistry.all.filter { k in
            k.available && (k.id == "wetter" || k.id == "countdown" || !Set(k.interests).isDisjoint(with: interests))
        }.enumerated().map { pair in
            BucketInstance(kind: pair.element.id, position: pair.offset, size: pair.element.defaultSize,
                           config: pair.element.defaultConfig)
        }
    }

    /// Nächster Bucket, der noch Einstellungen braucht – oder fertig
    private func nextSetup(after i: Int) {
        var j = i + 1
        while j < chosen.count {
            if let k = BucketRegistry.kind(chosen[j].bucket), k.settings != nil, k.needsSetup(chosen[j].config) {
                step = .setup(j); return
            }
            j += 1
        }
        step = .done
    }

    private func finish() {
        busy = true
        Task {
            do { try await store.finishOnboarding(with: chosen) } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

// MARK: Bausteine

/// Großer Titel + Untertitel wie in Apple-Setup-Assistenten
struct StepHeader: View {
    let symbol: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 44, weight: .semibold)).foregroundColor(Theme.accent)
            Text(title).font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
            Text(subtitle).font(.body).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}

/// Großer Weiter-Knopf unten
struct PrimaryButton: View {
    let title: String
    var busy = false
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).font(.headline).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(.white) }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundColor(.white)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(disabled ? Color.gray.opacity(0.4) : Theme.accent))
        }
        .disabled(disabled || busy)
        .padding(.bottom, 24)
    }
}

// MARK: 1. Willkommen + Mit Apple anmelden

struct WelcomeStep: View {
    @EnvironmentObject var store: AppStore
    @Binding var busy: Bool
    @Binding var error: String?
    @State private var nonce = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Hubert").font(.system(size: 56, weight: .bold))
            Text("Alles Wichtige auf einen Blick –\nund weniger Zeit am Handy.")
                .font(.title3).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
            Spacer()
            if busy { ProgressView() }
            SignInWithAppleButton(.signIn) { req in
                nonce = Self.randomNonce()
                req.requestedScopes = [.fullName]
                req.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Deine Daten liegen geschützt in deinem Konto. Kalender und Gesundheitsdaten bleiben auf dem Gerät.")
                .font(.footnote).foregroundColor(Theme.secondary).multilineTextAlignment(.center)
                .padding(.bottom, 24)
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code != .canceled { error = e.localizedDescription }
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
                error = "Apple hat keine Anmeldedaten geliefert."; return
            }
            let name = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            busy = true
            Task {
                do {
                    try await SupabaseClient.shared.signInWithApple(idToken: token, nonce: nonce)
                    await store.signedIn(name: name)
                } catch { self.error = "Anmeldung fehlgeschlagen: \(error.localizedDescription)" }
                busy = false
            }
        }
    }

    // Warum Nonce: Supabase prüft damit, dass das Apple-Token genau für diese Anmeldung erstellt wurde.
    static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }
    static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: 2. Haushalt

struct HouseholdStep: View {
    @EnvironmentObject var store: AppStore
    @Binding var busy: Bool
    @Binding var error: String?
    let onNext: () -> Void

    @State private var joinMode = false
    @State private var name = "Unser Zuhause"
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            StepHeader(symbol: "house.fill", title: "Dein Haushalt",
                       subtitle: "Küche, Einkaufsliste und Haushalts-Tools teilst du mit allen im Haushalt.")
            Picker("", selection: $joinMode) {
                Text("Neu anlegen").tag(false)
                Text("Mit Code beitreten").tag(true)
            }
            .pickerStyle(.segmented)
            if joinMode {
                TextField("Einladungscode, z. B. K7M2QX", text: $code)
                    .textInputAutocapitalization(.characters).disableAutocorrection(true)
                    .font(.title3.monospaced()).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            } else {
                TextField("Name des Haushalts", text: $name)
                    .font(.title3).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            }
            Spacer()
            PrimaryButton(title: "Weiter", busy: busy, disabled: joinMode ? code.count < 6 : name.isEmpty) {
                busy = true
                Task {
                    do {
                        if joinMode { try await store.joinHousehold(code: code) } else { try await store.createHousehold(name: name) }
                        onNext()
                    } catch { self.error = joinMode ? "Diesen Code gibt es nicht." : error.localizedDescription }
                    busy = false
                }
            }
        }
    }
}

// MARK: 3. Interessen

struct InterestsStep: View {
    @Binding var selected: Set<String>
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(symbol: "sparkles", title: "Was interessiert dich?",
                       subtitle: "Danach schlägt Hubert passende Buckets vor. Ändern kannst du alles später.")
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(Interest.all) { i in
                        let on = selected.contains(i.id)
                        Button {
                            if on { selected.remove(i.id) } else { selected.insert(i.id) }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: i.symbol).font(.title2)
                                Text(i.name).font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92)
                            .foregroundColor(on ? .white : .primary)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? Theme.accent : Theme.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            PrimaryButton(title: selected.isEmpty ? "Überspringen" : "Weiter", action: onNext)
        }
    }
}

// MARK: 4. Buckets auswählen

struct BucketPickStep: View {
    let interests: Set<String>
    @Binding var chosen: [BucketInstance]
    let onNext: () -> Void

    private var suggested: [BucketKind] {
        BucketRegistry.all.filter { !Set($0.interests).isDisjoint(with: interests) || $0.id == "wetter" || $0.id == "countdown" }
    }
    private var others: [BucketKind] { BucketRegistry.all.filter { k in !suggested.contains { $0.id == k.id } } }

    var body: some View {
        VStack(spacing: 12) {
            StepHeader(symbol: "square.grid.2x2.fill", title: "Deine Buckets",
                       subtitle: "Was soll auf deiner Startseite sein? Grau markierte kommen bald.")
            List {
                Section("Für dich vorgeschlagen") { ForEach(suggested) { row($0) } }
                if !others.isEmpty { Section("Weitere") { ForEach(others) { row($0) } } }
            }
            .listStyle(.insetGrouped)
            PrimaryButton(title: "Weiter", disabled: chosen.isEmpty, action: onNext)
        }
    }

    private func row(_ kind: BucketKind) -> some View {
        let on = chosen.contains { $0.bucket == kind.id }
        return HStack {
            BucketRow(kind: kind, detail: kind.blurb)
            Spacer()
            if kind.available {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundColor(on ? Theme.accent : Theme.secondary)
            } else {
                Text("bald").font(.caption.weight(.semibold)).foregroundColor(Theme.secondary)
            }
        }
        .opacity(kind.available ? 1 : 0.55)
        .contentShape(Rectangle())
        .onTapGesture {
            guard kind.available else { return }
            if on { chosen.removeAll { $0.bucket == kind.id } }
            else { chosen.append(BucketInstance(kind: kind.id, position: chosen.count, size: kind.defaultSize, config: kind.defaultConfig)) }
        }
    }
}

// MARK: 5. Einstellungen pro Bucket

struct SetupStep: View {
    @Binding var instance: BucketInstance
    let onNext: () -> Void

    var body: some View {
        let kind = BucketRegistry.kind(instance.bucket)
        VStack(spacing: 16) {
            StepHeader(symbol: kind?.symbol ?? "gearshape", title: kind?.name ?? "",
                       subtitle: "Kurz einstellen, dann passt der Bucket zu dir.")
            ScrollView {
                if let settings = kind?.settings {
                    settings($instance.config)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                }
            }
            PrimaryButton(title: "Weiter", disabled: kind?.needsSetup(instance.config) ?? false, action: onNext)
        }
    }
}

// MARK: 6. Fertig

struct DoneStep: View {
    let busy: Bool
    let onFinish: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 72)).foregroundColor(.green)
            Text("Alles bereit").font(.largeTitle.weight(.bold))
            Text("Buckets hinzufügen, sortieren und einstellen kannst du jederzeit über das Zahnrad.")
                .foregroundColor(Theme.secondary).multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Los geht's", busy: busy, action: onFinish)
        }
    }
}
