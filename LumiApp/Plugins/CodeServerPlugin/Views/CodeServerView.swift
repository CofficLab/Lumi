import SwiftUI
import WebKit

/// Code Server WebView 视图
///
/// 使用 WKWebView 加载 code-server (localhost:8080)，提供完整的 VS Code 编辑体验。
struct CodeServerView: View {
    var body: some View {
        CodeServerWebView()
    }
}

/// WKWebView 的 SwiftUI 包装器
struct CodeServerWebView: NSViewRepresentable {
    /// code-server 地址
    let serverURL = URL(string: "http://localhost:8080")!

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // 允许本地文件访问和混合内容
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.plugInsEnabled = false

        let webView = WKWebView(frame: .zero, configuration: configuration)

        // 自动调整大小
        webView.autoresizingMask = [.width, .height]
        webView.allowsBackForwardNavigationGestures = true

        // 加载 code-server
        let request = URLRequest(url: serverURL)
        webView.load(request)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 无需更新
    }
}
