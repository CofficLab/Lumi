import SwiftUI
import WebKit
import AppKit
import LumiUI
import KitMail

/// 阅读窗格：头部信息 + 操作条 + HTML/纯文本正文 + 附件条。
///
/// 安全策略（计划 §6）：HTML 经 `MailHTMLContentView` 渲染，禁 JS、
/// 默认拦截远程资源并提供「加载远程内容」提示条；无 HTML 时纯文本降级。
public struct MailReaderView: View {
    @LumiTheme private var theme: any LumiUITheme

    let detail: MailMessageDetail

    /// 是否已由用户授权加载远程图片/样式；每封邮件默认关闭。
    @State private var allowsRemoteContent = false

    public init(detail: MailMessageDetail) {
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let html = detail.htmlBody, !html.isEmpty {
                        if !allowsRemoteContent {
                            remoteContentBar
                        }
                        MailHTMLContentView(
                            html: html,
                            allowsRemoteContent: allowsRemoteContent
                        )
                    } else {
                        Text(detail.plainTextBody?.isEmpty == false ? detail.plainTextBody! : "（无正文）")
                            .font(.appBody)
                            .foregroundColor(theme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            if !detail.attachments.isEmpty {
                Divider()
                MailAttachmentBarView(attachments: detail.attachments)
            }
        }
        // 切换到另一封邮件时重置授权，避免远程内容在未确认时自动加载。
        .onChange(of: detail.summary.uid) { _ in
            allowsRemoteContent = false
        }
    }

    /// 远程内容授权条：默认拦截，用户明确点击后才放行。
    private var remoteContentBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
            Text("为保护隐私，已拦截远程图片和样式。")
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            Spacer()
            AppButton("加载远程内容", style: .secondary, size: .small) {
                allowsRemoteContent = true
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.appListRowBackground)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detail.summary.subject.isEmpty ? "（无主题）" : detail.summary.subject)
                .font(.appTitle)
                .foregroundColor(theme.textPrimary)
            HStack(spacing: 6) {
                Text("发件人")
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
                Text(fromText(detail.summary.from))
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text(detail.summary.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            }
            if !detail.summary.to.isEmpty {
                HStack(spacing: 6) {
                    Text("收件人")
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                    Text(detail.summary.to.map(\.email).joined(separator: ", "))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func fromText(_ address: MailAddress?) -> String {
        guard let address else { return "未知" }
        if let displayName = address.displayName, !displayName.isEmpty {
            return "\(displayName) <\(address.email)>"
        }
        return address.email
    }
}

// MARK: - HTML 渲染（禁 JS / 拦截远程资源）

/// WKWebView 封装：`javaScriptEnabled = false`；默认经 CSP 在 WebKit 内容层
/// 拦截全部远程子资源（图片/样式/字体），仅当用户点击「加载远程内容」时放行。
public struct MailHTMLContentView: NSViewRepresentable {
    let html: String
    /// 是否允许加载远程资源（由外部状态控制，默认 false）。
    var allowsRemoteContent = false

    public init(html: String, allowsRemoteContent: Bool = false) {
        self.html = html
        self.allowsRemoteContent = allowsRemoteContent
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences = preferences
        // 严格：不加载任何远程资源，除非用户授权
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.allowRemote = allowsRemoteContent
        // 内容或授权状态变化时重新加载，避免每次 update 重绘闪烁
        if coordinator.loadedHTML != html || coordinator.loadedAllowsRemote != allowsRemoteContent {
            coordinator.loadedHTML = html
            coordinator.loadedAllowsRemote = allowsRemoteContent
            load(html, into: webView, allowsRemoteContent: allowsRemoteContent)
        }
    }

    private func load(_ html: String, into webView: WKWebView, allowsRemoteContent: Bool) {
        webView.loadHTMLString(
            Self.baseHTML(with: html, allowsRemoteContent: allowsRemoteContent),
            baseURL: nil
        )
    }

    /// 包装：深色适配 + 基础排版。
    ///
    /// 远程内容策略落在 CSP 上：未授权时 `default-src 'none'` 让 WebKit 直接
    /// 拒绝所有远程子资源请求（`WKNavigationDelegate` 只覆盖导航动作，不覆盖
    /// 图片/样式等子资源，不能用来实现该策略）。授权后不再注入限制性策略。
    static func baseHTML(with body: String, allowsRemoteContent: Bool) -> String {
        let policy = allowsRemoteContent
            ? ""
            : """
              <meta http-equiv="Content-Security-Policy" \
              content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:">
              """
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        \(policy)
        <style>
          body { font-family: -apple-system, system-ui; font-size: 14px;
                 line-height: 1.6; color: #1d1d1f; margin: 0; padding: 0;
                 word-wrap: break-word; }
          img, video, iframe { max-width: 100%; height: auto; }
          table { max-width: 100%; border-collapse: collapse; }
          td, th { padding: 4px 8px; border: 1px solid #d2d2d7; }
          a { color: #0066cc; }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    /// 导航决策：用户点击的远程链接交给系统浏览器；其余远程导航仅在授权后放行。
    enum NavigationDecision: Equatable {
        case allow
        case cancel
        case openExternally(URL)
    }

    static func navigationDecision(
        for url: URL?,
        navigationType: WKNavigationType,
        allowsRemoteContent: Bool
    ) -> NavigationDecision {
        guard let url, isRemote(url) else { return .allow }
        if navigationType == .linkActivated {
            return .openExternally(url)
        }
        return allowsRemoteContent ? .allow : .cancel
    }

    static func isRemote(_ url: URL) -> Bool {
        url.scheme == "http" || url.scheme == "https"
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator: NSObject, WKNavigationDelegate {
        var allowRemote = false
        /// 已加载内容与授权状态（用于判断是否需要重新加载）。
        var loadedHTML: String?
        var loadedAllowsRemote: Bool?

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let decision = MailHTMLContentView.navigationDecision(
                for: navigationAction.request.url,
                navigationType: navigationAction.navigationType,
                allowsRemoteContent: allowRemote
            )
            switch decision {
            case .allow:
                decisionHandler(.allow)
            case .cancel:
                decisionHandler(.cancel)
            case .openExternally(let url):
                // 邮件内的链接交给系统浏览器，阅读窗格不承担网页导航。
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}

// MARK: - 附件条

/// 附件列表：图标 + 文件名 + 大小；预览/打开由宿主 Phase 4 完善（QLPreview 预留）。
public struct MailAttachmentBarView: View {
    @LumiTheme private var theme: any LumiUITheme

    let attachments: [MailAttachment]

    public init(attachments: [MailAttachment]) {
        self.attachments = attachments
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("附件（\(attachments.count)）")
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
            ForEach(attachments) { attachment in
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .font(.appCaption)
                        .foregroundColor(theme.primary)
                    Text(attachment.filename)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if attachment.size > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: attachment.size, countStyle: .file))
                            .font(.appCaption)
                            .foregroundColor(theme.textTertiary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
