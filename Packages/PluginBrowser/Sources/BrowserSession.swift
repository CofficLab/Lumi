import Combine
import Foundation
import WebKit

@MainActor
final class BrowserSession: NSObject, ObservableObject, WKNavigationDelegate {
    enum SessionError: LocalizedError {
        case invalidURL
        case noPage
        case navigationTimedOut
        case navigationReplaced
        case navigationCancelled
        case blockedLocalNavigation

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Enter a valid HTTP or HTTPS address."
            case .noPage: "This conversation does not have an open browser page yet."
            case .navigationTimedOut: "The page did not finish loading in time."
            case .navigationReplaced: "The page navigation was replaced by a newer request."
            case .navigationCancelled: "Page loading was cancelled."
            case .blockedLocalNavigation: "Navigation to a local or private network address was blocked. Open that address directly and approve the access request first."
            }
        }
    }

    let id = UUID()
    let conversationID: UUID
    let webView: WKWebView

    @Published private(set) var title = "New Tab"
    @Published private(set) var urlString = ""
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false

    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var navigationTimeoutTask: Task<Void, Never>?
    private var navigationToken: UUID?
    private var approvedLocalHost: String?

    init(conversationID: UUID) {
        self.conversationID = conversationID
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func navigate(to url: URL, allowLocalAccess: Bool = false) async throws {
        if navigationContinuation != nil {
            finishNavigation(.failure(SessionError.navigationReplaced), token: navigationToken)
            webView.stopLoading()
        }

        let token = UUID()
        navigationToken = token
        approvedLocalHost = allowLocalAccess ? url.host?.lowercased() : nil
        isLoading = true
        try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            navigationTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                self?.finishNavigation(.failure(SessionError.navigationTimedOut), token: token)
            }
            guard webView.load(URLRequest(url: url)) != nil else {
                finishNavigation(.failure(SessionError.invalidURL), token: token)
                return
            }
        }
    }

    func readPage(maxCharacters: Int) async throws -> String {
        let limit = min(max(maxCharacters, 500), 20_000)
        let script = """
        (() => {
          const text = document.body ? document.body.innerText : "";
          return {
            title: document.title || "",
            url: location.href,
            text: text.slice(0, \(limit)),
            truncated: text.length > \(limit),
            controls: Array.from(document.querySelectorAll("a[href],button,input,textarea,select,[role=button]"))
              .filter(el => el.getClientRects().length > 0)
              .slice(0, 80)
              .map((el, index) => {
                const ref = `lumi-${index + 1}`;
                el.setAttribute("data-lumi-browser-ref", ref);
                const label = el.getAttribute("aria-label") || el.innerText || el.getAttribute("placeholder") || el.getAttribute("title") || "";
                let href = el.tagName === "A" ? el.href : "";
                if (href) {
                  try {
                    const link = new URL(href);
                    for (const key of ["token", "access_token", "api_key", "key", "password", "secret", "code"]) {
                      if (link.searchParams.has(key)) link.searchParams.set(key, "[redacted]");
                    }
                    href = link.href;
                  } catch (_) {}
                }
                return { ref, tag: el.tagName.toLowerCase(), type: el.getAttribute("type") || "", label: label.trim().replace(/\\s+/g, " ").slice(0, 160), href };
              })()
          };
        })()
        """
        guard let page = try await webView.evaluateJavaScript(script) as? [String: Any] else {
            throw SessionError.noPage
        }
        let pageTitle = page["title"] as? String ?? title
        let pageURL = page["url"] as? String ?? urlString
        let text = page["text"] as? String ?? ""
        let truncated = page["truncated"] as? Bool ?? false
        let controls = (page["controls"] as? [[String: Any]] ?? []).map { item in
            let ref = item["ref"] as? String ?? ""
            let tag = item["tag"] as? String ?? "element"
            let type = item["type"] as? String ?? ""
            let label = (item["label"] as? String ?? "").nonEmpty ?? "(no label)"
            let href = (item["href"] as? String ?? "").nonEmpty.map { " → \($0)" } ?? ""
            let descriptor = type.isEmpty ? tag : "\(tag) type=\(type)"
            return "- @\(ref) [\(descriptor)] \(label)\(href)"
        }.joined(separator: "\n")
        return """
        # \(pageTitle)
        URL: \(pageURL)

        \(text)
        \(controls.isEmpty ? "" : "\n\nInteractive elements (refs are valid until the page changes):\n\(controls)")
        \(truncated ? "\n[Page text truncated. Call browser_read with a smaller scope or continue by interacting with the page.]" : "")
        """
    }

    func click(elementRef: String) async throws -> URL? {
        guard Self.isValidElementRef(elementRef) else { throw SessionError.noPage }
        let script = """
        (() => {
          const el = document.querySelector('[data-lumi-browser-ref="\(elementRef)"]');
          if (!el) throw new Error("Element reference is stale. Read the page again.");
          if (el.tagName === "A" && el.href) return { href: el.href };
          el.click();
          return { href: "" };
        })()
        """
        guard let result = try await webView.evaluateJavaScript(script) as? [String: Any] else {
            throw SessionError.noPage
        }
        guard let href = result["href"] as? String, !href.isEmpty else {
            await waitForInteractionNavigation()
            return nil
        }
        guard let url = URL(string: href), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw SessionError.invalidURL
        }
        return url
    }

    func type(_ text: String, into elementRef: String) async throws {
        guard Self.isValidElementRef(elementRef), text.count <= 10_000 else { throw SessionError.noPage }
        let encoded = try JSONSerialization.data(withJSONObject: [text])
        guard let literal = String(data: encoded, encoding: .utf8) else { throw SessionError.noPage }
        let script = """
        (() => {
          const el = document.querySelector('[data-lumi-browser-ref="\(elementRef)"]');
          if (!el) throw new Error("Element reference is stale. Read the page again.");
          if (!(el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement) || ["password", "file", "hidden"].includes((el.type || "").toLowerCase())) {
            throw new Error("This control does not accept text entry.");
          }
          const value = \(literal)[0];
          const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), "value")?.set;
          if (!setter) throw new Error("This control cannot be edited.");
          setter.call(el, value);
          el.dispatchEvent(new Event("input", { bubbles: true }));
          el.dispatchEvent(new Event("change", { bubbles: true }));
          return true;
        })()
        """
        _ = try await webView.evaluateJavaScript(script)
    }

    private static func isValidElementRef(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 48 && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    func reload() {
        webView.reload()
    }

    func stop() {
        webView.stopLoading()
        finishNavigation(.failure(SessionError.navigationCancelled), token: navigationToken)
        isLoading = false
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        updatePageState(from: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        updatePageState(from: webView)
        finishNavigation(.success(()), token: navigationToken)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        updatePageState(from: webView)
        finishNavigation(.failure(error), token: navigationToken)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        updatePageState(from: webView)
        finishNavigation(.failure(error), token: navigationToken)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let host = navigationAction.request.url?.host,
              BrowserSessionManager.isLocalHost(host),
              host.lowercased() != approvedLocalHost else {
            return .allow
        }
        finishNavigation(.failure(SessionError.blockedLocalNavigation), token: navigationToken)
        return .cancel
    }

    private func updatePageState(from webView: WKWebView) {
        title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? webView.url?.host ?? "Web Page"
        urlString = webView.url?.absoluteString ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    private func waitForInteractionNavigation() async {
        var started = webView.isLoading
        for _ in 0..<5 where !started {
            try? await Task.sleep(nanoseconds: 100_000_000)
            started = webView.isLoading
        }
        guard started else { return }
        for _ in 0..<150 {
            guard webView.isLoading else { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func finishNavigation(_ result: Result<Void, Error>, token: UUID?) {
        guard let token, token == navigationToken, let continuation = navigationContinuation else { return }
        navigationContinuation = nil
        navigationTimeoutTask?.cancel()
        navigationTimeoutTask = nil
        navigationToken = nil
        isLoading = false
        continuation.resume(with: result)
    }
}

@MainActor
public final class BrowserSessionManager: ObservableObject {
    @Published private(set) var activeConversationID: UUID?
    @Published private(set) var activeSession: BrowserSession?

    private var sessions: [UUID: BrowserSession] = [:]
    private let standaloneSessionID = UUID()
    var onRequestPresentation: (@MainActor () -> Void)?

    public init() {}

    func selectConversation(_ conversationID: UUID?) {
        activeConversationID = conversationID
        activeSession = conversationID.flatMap { sessions[$0] }
    }

    func open(_ rawAddress: String, conversationID: UUID, allowLocalAccess: Bool = false) async throws -> String {
        guard let url = Self.normalizedURL(rawAddress) else {
            throw BrowserSession.SessionError.invalidURL
        }
        if Self.isLocalHost(url.host ?? ""), !allowLocalAccess {
            throw BrowserSession.SessionError.blockedLocalNavigation
        }
        onRequestPresentation?()
        let session = session(for: conversationID)
        activeConversationID = conversationID
        activeSession = session
        try await session.navigate(to: url, allowLocalAccess: allowLocalAccess)
        return "Opened \(session.title) (\(session.urlString)). Use browser_read to inspect the page."
    }

    func read(conversationID: UUID, maxCharacters: Int) async throws -> String {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session
        return try await session.readPage(maxCharacters: maxCharacters)
    }

    func interact(action: String, elementRef: String, text: String?, conversationID: UUID) async throws -> String {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session
        switch action {
        case "click":
            if let destination = try await session.click(elementRef: elementRef) {
                return try await open(destination.absoluteString, conversationID: conversationID, allowLocalAccess: true)
            }
            return "Clicked @\(elementRef). Read the page to inspect the result."
        case "type":
            guard let text else { throw BrowserSession.SessionError.noPage }
            try await session.type(text, into: elementRef)
            return "Entered text into @\(elementRef). The page was not submitted. Read the page to verify the field."
        default:
            throw BrowserSession.SessionError.noPage
        }
    }

    func navigateAddressBar(_ address: String) {
        let conversationID = activeConversationID ?? standaloneSessionID
        Task { try? await open(address, conversationID: conversationID, allowLocalAccess: true) }
    }

    private func session(for conversationID: UUID) -> BrowserSession {
        if let session = sessions[conversationID] { return session }
        let session = BrowserSession(conversationID: conversationID)
        sessions[conversationID] = session
        return session
    }

    nonisolated private static func normalizedURL(_ address: String) -> URL? {
        var value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") { value = "https://" + value }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil else {
            return nil
        }
        return components.url
    }

    nonisolated static func requiresLocalAccessApproval(_ rawAddress: String) -> Bool {
        guard let url = normalizedURL(rawAddress) else { return true }
        return isLocalHost(url.host ?? "")
    }

    nonisolated static func isLocalHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if ["localhost", "::1"].contains(host)
            || [".localhost", ".local", ".internal", ".lan"].contains(where: host.hasSuffix) {
            return true
        }
        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        if octets.count == 4 {
            let a = octets[0], b = octets[1]
            return a == 0 || a == 10 || a == 127 || (a == 169 && b == 254)
                || (a == 172 && (16...31).contains(b)) || (a == 192 && b == 168)
        }
        return host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80:")
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
