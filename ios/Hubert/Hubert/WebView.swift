import SwiftUI
import WebKit

// ============================================================
// WebView: zeigt die Web-App in einem WKWebView an.
// - Daten (Haushalts-Schlüssel, Abhak-Stand) bleiben dauerhaft gespeichert
// - Timer-Töne dürfen ohne vorheriges Antippen abgespielt werden
// - Nach unten ziehen lädt die Seite neu (z. B. nach einem Update)
// - Ohne Internet: Hinweis mit "Erneut versuchen" statt weißer Seite
// ============================================================
struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Warum .default(): Daten der Seite (localStorage) überleben App-Neustarts
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        // Warum leer: Der Timer soll auch piepen dürfen, wenn vorher niemand getippt hat
        config.mediaTypesRequiringUserActionForPlayback = []
        // Warum: So weiß die Web-App, dass sie in der Hubert-App läuft (z. B. für den Kalender)
        config.userContentController.addUserScript(WKUserScript(
            source: "window.HUBERT_APP = true;", injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.965, green: 0.945, blue: 0.914, alpha: 1) // wie die App (#f6f1e9)

        // Nach unten ziehen = neu laden
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.reload(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        context.coordinator.webView = webView
        context.coordinator.calendar = CalendarBridge(webView: webView)
        // 23–6 Uhr: schwarz und minimale Helligkeit (siehe NightMode.swift)
        context.coordinator.night = NightMode(host: webView)
        context.coordinator.load()

        // Kommt die App wieder in den Vordergrund und war vorher offline: neu versuchen
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.becameActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let url: URL
        weak var webView: WKWebView?
        var calendar: CalendarBridge?
        var night: NightMode?
        var failed = false

        init(url: URL) { self.url = url }

        func load() {
            // Warum ohne Cache: Die Startseite soll immer frisch von GitHub kommen,
            // damit Updates sofort ankommen.
            webView?.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
        }

        @objc func reload(_ sender: UIRefreshControl) {
            load()
            sender.endRefreshing()
        }

        @objc func becameActive() {
            night?.refresh()
            if failed { load() } else { calendar?.push() }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Nur die echte App zählt als Erfolg, nicht die Offline-Ersatzseite
            if webView.url?.host == url.host {
                failed = false
                // Termine schicken (fragt beim allerersten Mal um Erlaubnis)
                calendar?.requestAndPush()
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showOffline(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showOffline(error)
        }

        /// Einfache Ersatzseite, wenn kein Internet da ist
        private func showOffline(_ error: Error) {
            failed = true
            let html = """
            <html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
            <body style="font-family:-apple-system;background:#f6f1e9;color:#2b2420;display:flex;
              align-items:center;justify-content:center;height:100vh;margin:0;text-align:center">
            <div><div style="font-size:64px">📡</div>
            <h2>Keine Verbindung</h2>
            <p style="color:#8a7d72">Ist das WLAN an? Die App versucht es automatisch wieder.</p>
            <a href="\(url.absoluteString)" style="display:inline-block;margin-top:12px;padding:14px 24px;
              background:#c2410c;color:#fff;border-radius:12px;text-decoration:none;font-size:20px">Erneut versuchen</a>
            </div></body></html>
            """
            webView?.loadHTMLString(html, baseURL: nil)
            // Nach 30 Sekunden selbst nochmal probieren
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                if self?.failed == true { self?.load() }
            }
        }

        /// Links zu anderen Seiten (z. B. Quellen) in Safari öffnen, nicht in der App
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let target = action.request.url, action.navigationType == .linkActivated,
               target.host != url.host {
                UIApplication.shared.open(target)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
