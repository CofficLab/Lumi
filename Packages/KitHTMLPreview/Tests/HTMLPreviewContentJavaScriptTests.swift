import AppKit
import Foundation
import Testing
import WebKit

@testable import KitHTMLPreview

/// 预览必须与导出管线一致地禁用内容 JavaScript（#494）。
///
/// 旧实现用默认 `WKWebViewConfiguration`，`<body onload=…>` 等内联事件处理器
/// 会在预览里执行（还能调用原生消息通道），而导出器设了
/// `allowsContentJavaScript = false`，同一文档因此呈现不同 DOM。
/// 修复把配置收敛到 `HTMLPreviewWebViewFactory`，统一禁用内容 JS；
/// 原生 `evaluateJavaScript` 注入的选区/桥接监听器不受影响。
@Suite("HTML preview content JavaScript (#494)")
@MainActor
struct HTMLPreviewContentJavaScriptTests {

    @Test("预览配置禁用内容 JavaScript")
    func configurationDisablesContentJavaScript() {
        let config = HTMLPreviewWebViewFactory.makeConfiguration(userContentController: WKUserContentController())
        #expect(config.defaultWebpagePreferences.allowsContentJavaScript == false)
    }

    @Test("内联事件处理器与 script 标签都不执行")
    func inlineHandlersAndScriptTagsDoNotRun() async throws {
        let webView = try await makePreviewWebView(html: """
        <html><body data-test-ready onload="window.__inlineRan = true">
        <script>window.__scriptRan = true;</script>
        <div id="t">x</div>
        </body></html>
        """)
        #expect(try await webView.evaluateJavaScript("window.__inlineRan === true") as? Bool == false)
        #expect(try await webView.evaluateJavaScript("window.__scriptRan === true") as? Bool == false)
    }

    @Test("原生注入的选区桥接监听器仍正常触发")
    func nativeInjectedBridgeStillWorks() async throws {
        let webView = try await makePreviewWebView(html: "<html><body data-test-ready><div id=\"t\">x</div></body></html>")
        // 模拟选区脚本：经原生 evaluateJavaScript 安装事件监听器，再派发事件。
        _ = try await webView.evaluateJavaScript("""
        window.__handlerRan = false;
        document.getElementById('t').addEventListener('contextmenu', function () { window.__handlerRan = true; });
        """)
        _ = try await webView.evaluateJavaScript("""
        document.getElementById('t').dispatchEvent(new MouseEvent('contextmenu', { bubbles: true }));
        """)
        #expect(try await webView.evaluateJavaScript("window.__handlerRan === true") as? Bool == true)
    }

    /// 用与生产完全一致的配置工厂构造 WebView，确保回归直接覆盖生产配置路径。
    private func makePreviewWebView(html: String) async throws -> WKWebView {
        let config = HTMLPreviewWebViewFactory.makeConfiguration(userContentController: WKUserContentController())
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 400), configuration: config)
        webView.loadHTMLString(html, baseURL: nil)
        for _ in 0..<200 {
            if (try? await webView.evaluateJavaScript(
                "document.readyState === 'complete' && document.body.hasAttribute('data-test-ready')"
            )) as? Bool == true {
                return webView
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("WKWebView did not finish loading")
        return webView
    }
}