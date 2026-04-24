import SwiftUI
import WebKit

/// WKWebView 的 SwiftUI 包装器
///
/// 负责渲染 code-server 的 Web 界面。
struct CodeServerWebView: NSViewRepresentable {
    /// 要加载的 URL
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.allowsBackForwardNavigationGestures = true

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 无需更新
    }
}
