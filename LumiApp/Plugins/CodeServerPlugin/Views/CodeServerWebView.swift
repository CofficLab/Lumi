import SwiftUI
import WebKit

/// WKWebView 的 SwiftUI 包装器
///
/// 负责渲染 code-server 的 Web 界面。
struct CodeServerWebView: NSViewRepresentable {
    /// 要加载的 URL
    let url: URL
    
    /// 是否注入自定义 CSS，默认为 true
    var injectCSS: Bool = false

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // 根据配置决定是否注入 CSS 隐藏 VS Code 特定 UI 元素
        if injectCSS {
            let userContentController = WKUserContentController()
            let cssScript = WKUserScript(
                source: CodeServerCSS.injectionScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
            userContentController.addUserScript(cssScript)
            configuration.userContentController = userContentController
        }

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
