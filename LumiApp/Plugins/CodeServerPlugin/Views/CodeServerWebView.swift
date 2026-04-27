import SwiftUI
import WebKit

/// WKWebView 的 SwiftUI 包装器
///
/// 负责渲染 code-server 的 Web 界面。
struct CodeServerWebView: NSViewRepresentable {
    /// 要加载的 URL
    let url: URL
    
    /// 是否注入自定义 CSS，默认为 false（优先使用 settings.json）
    var injectCSS: Bool = false
    
    /// 是否需要重新加载
    var reloadTrigger: Bool = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        webView.navigationDelegate = context.coordinator

        context.coordinator.lastRequestedURL = url
        context.coordinator.lastReloadTrigger = reloadTrigger
        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let shouldReloadForURLChange = context.coordinator.lastRequestedURL != url
        let shouldReloadForTrigger = reloadTrigger && !context.coordinator.lastReloadTrigger

        context.coordinator.lastRequestedURL = url
        context.coordinator.lastReloadTrigger = reloadTrigger

        // URL 变化或收到重载信号（上升沿）时触发 reload
        if shouldReloadForURLChange || shouldReloadForTrigger {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastRequestedURL: URL?
        var lastReloadTrigger: Bool = false

        override init() {}

        // WebContent 进程异常终止时自动恢复，避免页面长期空白
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            reloadAfterFailure(webView, error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            reloadAfterFailure(webView, error: error)
        }

        private func reloadAfterFailure(_ webView: WKWebView, error: Error) {
            let nsError = error as NSError
            // 忽略用户主动取消（例如新请求覆盖旧请求）的错误
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                webView.reload()
            }
        }
    }
}
