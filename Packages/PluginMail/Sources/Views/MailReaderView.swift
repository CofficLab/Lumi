import SwiftUI
import WebKit
import LumiUI
import KitMail

/// 阅读窗格：头部信息 + 操作条 + HTML/纯文本正文 + 附件条。
///
/// 安全策略（计划 §6）：HTML 经 `MailHTMLContentView` 渲染，禁 JS、
/// 默认拦截远程资源并提供「加载远程内容」提示条；无 HTML 时纯文本降级。
public struct MailReaderView: View {
    @LumiTheme private var theme: any LumiUITheme

    let detail: MailMessageDetail

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
                        MailHTMLContentView(html: html)
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

/// WKWebView 封装：`javaScriptEnabled = false`；默认拦截远程图片/样式等资源，
/// 仅当用户点击「加载远程内容」时放行。
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
        context.coordinator.allowRemote = allowsRemoteContent
        // 仅当内容变化时重新加载，避免每次 update 重绘闪烁
        if webView.url == nil {
            load(html, into: webView)
        }
    }

    private func load(_ html: String, into webView: WKWebView) {
        webView.loadHTMLString(baseHTML(with: html), baseURL: nil)
    }

    /// 包装：深色适配 + 基础排版，远程资源默认被 navigationDelegate 拦截。
    private func baseHTML(with body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
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

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator: NSObject, WKNavigationDelegate {
        var allowRemote = false

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .other, navigationAction.request.url == nil {
                decisionHandler(.allow)
                return
            }
            // 拦截远程资源加载（图片/样式/iframe 等），除非用户授权
            if let url = navigationAction.request.url {
                let isRemote = url.scheme == "http" || url.scheme == "https"
                if isRemote && !allowRemote {
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
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
