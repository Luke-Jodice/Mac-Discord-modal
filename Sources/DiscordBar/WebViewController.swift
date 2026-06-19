import AppKit
import WebKit

/// Hosts Discord's own web app inside a WKWebView (an embedded browser),
/// so you log in once with your normal account and use Discord normally.
final class WebViewController: NSViewController, WKUIDelegate, WKNavigationDelegate {
    private(set) var webView: WKWebView!

    private static let discordURL = URL(string: "https://discord.com/app")!
    // Present as Safari so Discord serves the full web client instead of nagging
    // to download the desktop app.
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    private static let zoomKey = "pageZoom.v1"
    private static let sidebarKey = "channelsHidden.v1"

    /// Channel sidebar collapsed by default for a clean small window; toggled
    /// with the on-screen button or ⌘B.
    private var sidebarHidden: Bool =
        UserDefaults.standard.object(forKey: WebViewController.sidebarKey) as? Bool ?? true

    /// Always-hidden chrome plus a toggled rule for the channel sidebar. Targets
    /// the readable prefix of Discord's hashed class names (e.g. "guilds_a1b2c3").
    private static let minimalCSS = """
    [class*="guilds_"] { display: none !important; }        /* server rail   */
    [class*="membersWrap_"] { display: none !important; }   /* member list   */
    [class*="toolbar_"] { display: none !important; }       /* header tools  */
    html.dbar-collapsed [class*="sidebar_"] { display: none !important; } /* channels */
    """

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // persistent cookies → stays logged in
        config.mediaTypesRequiringUserActionForPlayback = []

        // Inject the minimal-view stylesheet before the page renders so the full
        // UI never flashes. The <style> persists across Discord's SPA navigation.
        let initialClass = sidebarHidden
            ? "document.documentElement.classList.add('dbar-collapsed');"
            : ""
        let injectCSS = """
        (function() {
            var style = document.createElement('style');
            style.id = 'discordbar-minimal';
            style.textContent = `\(Self.minimalCSS)`;
            document.documentElement.appendChild(style);
            \(initialClass)
        })();
        """
        let script = WKUserScript(source: injectCSS,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.customUserAgent = Self.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = self
        webView.navigationDelegate = self
        self.webView = webView

        let container = NSView()
        container.addSubview(webView)

        // Floating channel toggle, top-right where the hidden header toolbar was.
        let toggle = NSButton(
            image: NSImage(systemSymbolName: "sidebar.left",
                           accessibilityDescription: "Show or hide channels")!,
            target: self,
            action: #selector(toggleChannels(_:))
        )
        toggle.isBordered = false
        toggle.imageScaling = .scaleProportionallyDown
        toggle.contentTintColor = .white
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.wantsLayer = true
        toggle.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.45).cgColor
        toggle.layer?.cornerRadius = 7
        toggle.toolTip = "Show/hide channels (⌘B)"
        container.addSubview(toggle) // added after webView → drawn on top

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            toggle.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            toggle.widthAnchor.constraint(equalToConstant: 28),
            toggle.heightAnchor.constraint(equalToConstant: 28)
        ])
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let savedZoom = UserDefaults.standard.double(forKey: Self.zoomKey)
        if savedZoom > 0 { webView.pageZoom = savedZoom }
        webView.load(URLRequest(url: Self.discordURL))
    }

    // MARK: Channel sidebar toggle (⌘B / on-screen button)

    @objc func toggleChannels(_ sender: Any?) {
        sidebarHidden.toggle()
        UserDefaults.standard.set(sidebarHidden, forKey: Self.sidebarKey)
        let js = sidebarHidden
            ? "document.documentElement.classList.add('dbar-collapsed');"
            : "document.documentElement.classList.remove('dbar-collapsed');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: Zoom (wired to ⌘=/⌘+/⌘-/⌘0 via the View menu)

    @objc func zoomIn(_ sender: Any?) { applyZoom(webView.pageZoom + 0.1) }
    @objc func zoomOut(_ sender: Any?) { applyZoom(webView.pageZoom - 0.1) }
    @objc func actualSize(_ sender: Any?) { applyZoom(1.0) }

    private func applyZoom(_ value: CGFloat) {
        let clamped = min(max(value, 0.5), 2.0)
        webView.pageZoom = clamped
        UserDefaults.standard.set(Double(clamped), forKey: Self.zoomKey)
    }

    // MARK: WKUIDelegate / WKNavigationDelegate

    /// Keep Discord navigation inside the panel; send other links to the browser.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if let host = url.host, host.contains("discord") {
            webView.load(navigationAction.request)
        } else {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    /// Allow mic/camera for voice & video calls (also needs the usage strings
    /// in Info.plist; may be limited without a signed app).
    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}
