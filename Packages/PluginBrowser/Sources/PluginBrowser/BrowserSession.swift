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
        case invalidElementRef(String)
        case staleElementRef(String, detail: String)
        case interactionFailed(String)
        case missingTextForAction(BrowserInteractionAction)
        case waitTimedOut(String)
        case navigationUnavailable(String)
        case localNavigationNeedsApproval(String)
        case scriptTooLong
        case scriptFailed(String)
        case screenshotUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Enter a valid HTTP or HTTPS address."
            case .noPage: "This conversation does not have an open browser page yet."
            case .navigationTimedOut: "The page did not finish loading in time."
            case .navigationReplaced: "The page navigation was replaced by a newer request."
            case .navigationCancelled: "Page loading was cancelled."
            case .blockedLocalNavigation: "Navigation to a local or private network address was blocked. Open that address directly and approve the access request first."
            case .invalidElementRef(let raw):
                raw.isEmpty
                    ? "This action needs an element reference from browser_snapshot."
                    : "\"\(raw)\" is not a valid element reference. Use a ref from browser_snapshot, such as @lumi-3."
            case .staleElementRef(_, let detail):
                detail
            case .interactionFailed(let reason):
                reason.isEmpty ? "The interaction could not be completed." : reason
            case .missingTextForAction(let action):
                "The \(action.rawValue) action needs a text argument."
            case .waitTimedOut(let what):
                "Timed out waiting for \(what)."
            case .navigationUnavailable(let reason):
                reason
            case .localNavigationNeedsApproval(let host):
                "That link points to the local network address \(host). Opening it needs its own approval. "
                    + "Open it directly with browser_open so the user can approve it."
            case .scriptTooLong:
                "The script is too long. Keep it under 20000 characters."
            case .scriptFailed(let reason):
                "The script failed: \(reason)"
            case .screenshotUnavailable:
                "A screenshot could not be captured from this page."
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
    private var urlObservation: NSKeyValueObservation?
    /// ref 登记簿：记录已见过的元素特征，用于诊断失效 ref。
    private let refStore = BrowserElementRefStore()

    init(conversationID: UUID) {
        self.conversationID = conversationID
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observeURL()
    }

    private func observeURL() {
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in
                self?.syncPageState(from: webView)
            }
        }
    }

    private func syncPageState(from webView: WKWebView) {
        title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? webView.url?.host ?? "Web Page"
        urlString = webView.url?.absoluteString ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    /// 导航到指定地址。
    ///
    /// - Parameter localAccessApproved: 用户是否**已明确批准**访问本地/内网地址。
    ///   注意这是「已批准」而不是「是否需要批准」——早期用 `allowLocalAccess`
    ///   命名导致调用处把判断结果反向传参，审批语义一度漂移。
    func navigate(to url: URL, localAccessApproved: Bool = false) async throws {
        if navigationContinuation != nil {
            finishNavigation(.failure(SessionError.navigationReplaced), token: navigationToken)
            webView.stopLoading()
        }

        let token = UUID()
        navigationToken = token
        approvedLocalHost = localAccessApproved ? url.host?.lowercased() : nil
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

    /// 采集可访问性快照。
    ///
    /// 返回的是**结构化树**而非扁平文本：LLM 需要知道元素之间的从属关系
    /// （「这个按钮属于哪个表单」），才能决定操作顺序。
    func accessibilitySnapshot(interactiveOnly: Bool = false) async throws -> BrowserAccessibilitySnapshot {
        let script = BrowserAccessibilityScript.script(operation: "snapshot")
        guard let page = try await webView.evaluateJavaScript(script) as? [String: Any] else {
            throw SessionError.noPage
        }
        let rawNodes = page["nodes"] as? [[String: Any]] ?? []
        let nodes = BrowserAccessibilityNode.parseList(rawNodes)
        let tree = BrowserAccessibilityNode.buildTree(from: nodes)

        // 登记本次看到的元素特征，供后续交互诊断 stale ref。
        var signatures: [String: BrowserElementRefStore.ElementSignature] = [:]
        for node in nodes {
            signatures[node.ref] = BrowserElementRefStore.ElementSignature(role: node.role, name: node.name)
        }
        refStore.register(signatures: signatures)

        return BrowserAccessibilitySnapshot(
            pageTitle: title,
            pageURL: urlString,
            roots: tree,
            totalNodeCount: (page["total"] as? Int) ?? nodes.count
        )
    }

    /// 按 role / name / text 查找元素，返回匹配项的 ref。
    ///
    /// - Parameters:
    ///   - role: 角色名（如 `button`）；nil 表示不限。
    ///   - name: 可访问名（支持子串匹配）；nil 表示不限。
    ///   - text: 可见文本（支持子串匹配）；nil 表示不限。
    ///   - limit: 最多返回多少条。
    func findElements(role: String?, name: String?, text: String?, limit: Int = 20) async throws -> [BrowserAccessibilityNode] {
        let options: [String: Any] = [
            "role": role ?? "",
            "name": name ?? "",
            "text": text ?? "",
            "limit": limit,
        ]
        let script = BrowserAccessibilityScript.script(operation: "find", options: options)
        guard let page = try await webView.evaluateJavaScript(script) as? [String: Any] else {
            throw SessionError.noPage
        }
        let matches = page["matches"] as? [[String: Any]] ?? []
        return BrowserAccessibilityNode.parseList(matches)
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
        // 页面正文里可能藏着伪造的边界标记，先中和再交给上层包裹。
        let text = BrowserContentBoundary.neutralize(page["text"] as? String ?? "")
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

    /// 执行一次交互动作。
    ///
    /// 所有动作共用同一条链路：解析 ref → 执行 → 诊断 stale → 返回结果。
    /// stale 的诊断在这里统一处理，避免 LLM 拿到一句笼统的失败后反复重试死 ref。
    func performInteraction(
        action: BrowserInteractionAction,
        elementRef: String?,
        text: String?
    ) async throws -> BrowserInteractionResult {
        let normalizedRef = elementRef.flatMap { refStore.normalize($0) }
        if action.requiresElement && normalizedRef == nil {
            throw SessionError.invalidElementRef(elementRef ?? "")
        }
        if action.requiresText && (text?.isEmpty ?? true) {
            throw SessionError.missingTextForAction(action)
        }

        let script = BrowserInteractionScript.script(action: action, ref: normalizedRef, text: text)
        let raw = try await webView.evaluateJavaScript(script)
        guard let result = raw as? [String: Any] else {
            throw SessionError.noPage
        }

        let ok = (result["ok"] as? Bool) ?? false
        let message = (result["message"] as? String) ?? ""

        guard ok else {
            // stale ref：元素已不在页面上。
            if message.hasPrefix("STALE_REF:") {
                let missingRef = String(message.dropFirst("STALE_REF:".count))
                refStore.markStale(ref: missingRef, reason: "it is no longer present in the DOM")
                let detail = refStore.staleMessage(for: missingRef)
                    ?? "The element @\(missingRef) is no longer on the page."
                throw SessionError.staleElementRef(missingRef, detail: detail)
            }
            throw SessionError.interactionFailed(message)
        }

        // 点击链接时给出目标地址，交由上层决定是否发起导航。
        var destination: URL?
        if let href = result["href"] as? String, !href.isEmpty {
            if let url = URL(string: href), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                destination = url
            }
        }

        // 非链接交互后等待可能的页面跳转，避免调用方立刻读到旧页面。
        if destination == nil, action == .click || action == .press {
            await waitForInteractionNavigation()
        }

        let target = normalizedRef.map { "@\($0)" } ?? "the page"
        let detail = message.isEmpty ? "Done." : message
        return BrowserInteractionResult(
            navigationTarget: destination,
            message: "\(detail) (\(target)). Read the page to inspect the result."
        )
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

    /// 本次会话中已获批准访问的本地主机（小写）。
    var approvedLocalHostName: String? { approvedLocalHost }

    /// 某个本地主机是否已获批准。
    func hasApprovedLocalHost(_ host: String) -> Bool {
        guard let approved = approvedLocalHost else { return false }
        return approved == host.lowercased()
    }

    func waitForInteractionNavigation() async {
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

    /// 打开一个地址。
    ///
    /// - Parameter localAccessApproved: 用户是否**已明确批准**访问本地/内网地址。
    func open(_ rawAddress: String, conversationID: UUID, localAccessApproved: Bool = false) async throws -> String {
        guard let url = Self.normalizedURL(rawAddress) else {
            throw BrowserSession.SessionError.invalidURL
        }
        if Self.isLocalHost(url.host ?? ""), !localAccessApproved {
            throw BrowserSession.SessionError.blockedLocalNavigation
        }
        onRequestPresentation?()
        let session = session(for: conversationID)
        activeConversationID = conversationID
        activeSession = session
        try await session.navigate(to: url, localAccessApproved: localAccessApproved)
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

    func interact(
        action: BrowserInteractionAction,
        elementRef: String?,
        text: String?,
        conversationID: UUID
    ) async throws -> String {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session
        let result = try await session.performInteraction(action: action, elementRef: elementRef, text: text)

        // 点击链接后由上层发起导航。
        //
        // 关键：`allowLocalAccess` 必须反映**目标地址**的真实属性，
        // 不能因为「用户已经批准了这次点击」就一并放行本地地址。
        // 否则用户批准一次普通点击，就能被页面静默重定向到内网服务。
        if let destination = result.navigationTarget {
            let host = destination.host?.lowercased() ?? ""
            let isLocal = BrowserSessionManager.isLocalHost(host)

            // 用户批准的是「点击这个元素」，不是「访问内网地址」。
            // 因此指向内网的链接不能顺带放行，必须让内网访问单独走一次审批。
            // 但同一会话内已经批准过的主机可以继续访问——否则用户批准了
            // localhost:3000 后，在站内点链接反而会被拦下。
            if isLocal, !session.hasApprovedLocalHost(host) {
                throw BrowserSession.SessionError.localNavigationNeedsApproval(host)
            }
            return try await open(
                destination.absoluteString,
                conversationID: conversationID,
                localAccessApproved: isLocal
            )
        }
        return result.message
    }

    /// 采集可访问性快照。
    func snapshot(interactiveOnly: Bool, conversationID: UUID) async throws -> BrowserAccessibilitySnapshot {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session
        return try await session.accessibilitySnapshot(interactiveOnly: interactiveOnly)
    }

    /// 按 role / name / text 查找元素。
    func findElements(
        role: String?,
        name: String?,
        text: String?,
        limit: Int,
        conversationID: UUID
    ) async throws -> [BrowserAccessibilityNode] {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session
        return try await session.findElements(role: role, name: name, text: text, limit: limit)
    }

    /// 等待页面满足某个条件。
    func wait(
        condition: BrowserWaitCondition,
        value: String?,
        timeout: TimeInterval,
        conversationID: UUID
    ) async throws -> String {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session
        let result = try await session.wait(condition: condition, value: value, timeout: timeout)
        if result.timedOut {
            throw BrowserSession.SessionError.waitTimedOut(result.detail)
        }
        return result.detail
    }

    /// 执行导航。
    func navigate(
        action: BrowserNavigationAction,
        url: String?,
        conversationID: UUID
    ) async throws -> String {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session

        var destination: URL?
        if action == .goto {
            guard let raw = url, let parsed = Self.normalizedURL(raw) else {
                throw BrowserSession.SessionError.invalidURL
            }
            destination = parsed
        }

        // `goto` 的审批由工具层按目标地址判定（本地地址 → .high → 先审批）。
        // 走到这里说明审批已通过，因此本地地址视为「已批准」。
        // 其它动作（back/forward/reload）不涉及新地址，不受此影响。
        let approvedForLocalAccess = destination.map { Self.isLocalHost($0.host ?? "") } ?? false
        return try await session.navigate(action: action, url: destination, localAccessApproved: approvedForLocalAccess)
    }

    /// 执行页面 JavaScript。
    func evaluate(script: String, conversationID: UUID) async throws -> String {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session
        return try await session.evaluate(script: script)
    }

    /// 截取当前页面。
    func screenshot(fullPage: Bool, conversationID: UUID) async throws -> Data {
        guard let session = sessions[conversationID] else {
            throw BrowserSession.SessionError.noPage
        }
        activeConversationID = conversationID
        activeSession = session
        return try await session.screenshot(fullPage: fullPage)
    }

    /// Returns the current page title and URL for a conversation, or nil if no session exists.
    func status(conversationID: UUID) -> String? {
        guard let session = sessions[conversationID] else { return nil }
        return "Title: \(session.title)\nURL: \(session.urlString)"
    }

    func navigateAddressBar(_ address: String) {
        let conversationID = activeConversationID ?? standaloneSessionID
        // 用户亲手在地址栏输入地址，属于主动行为，视为已批准访问该地址。
        Task { try? await open(address, conversationID: conversationID, localAccessApproved: true) }
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
