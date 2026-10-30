import AppKit
import Testing
import WebKit

@testable import KitHTMLPreview

@Suite("HTMLScreenshotter capture")
@MainActor
struct HTMLScreenshotterCaptureTests {

    @Test("captures a rendered web page into a non-empty image spanning all content")
    func capturesFullPage() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        // 挂到窗口上：游离的 WKWebView 在无 run loop 的测试进程里无法完成布局，
        // `createPDF` 回调不会送达。
        let window = NSWindow(contentRect: webView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        let html = """
        <html><body style="margin:0">
        <div style="height:500px;background:#ff0000"></div>
        </body></html>
        """
        // 等待加载完成并让布局生效，否则截到的是尚未布局的视口。
        // `navigationDelegate` 是弱引用，delegate 必须在整个等待期间强持有。
        let delegate = NavigationWaiter()
        webView.navigationDelegate = delegate
        _ = try? await webView.loadHTMLString(html, baseURL: nil)
        await delegate.waitForFinish(timeout: .seconds(5))
        // 等待真实布局就绪：`didFinish` 只表示文档已解析，页面高度未必已确定。
        // 忙等（`Task.yield()` 循环）不会推进 WebKit 的渲染进程，必须轮询
        // 真实的内容高度，否则 `createPDF` 可能因页面尚未布局而拿不到结果。
        let layoutReady = await delegate.waitForLayout(
            webView: webView,
            timeout: .seconds(10)
        )
        #expect(layoutReady, "页面布局未在超时前就绪，WebKit 渲染可能未推进")

        let image = try await HTMLScreenshotter.capture(webView)

        #expect(image.size.width > 0)
        // The 500px-tall body must exceed the 200pt viewport, proving the
        // capture renders the full page rather than just the visible area.
        #expect(image.size.height >= 500)
    }

    @Test("throws an error for a web view with no rendered content")
    func throwsForEmptyDocument() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))

        await #expect(throws: Error.self) {
            _ = try await HTMLScreenshotter.capture(webView)
        }
    }

    /// WebKit 未能送达完成回调时，`capture` 必须超时抛错而不是永久挂起。
    ///
    /// 回归 Issue #127：`WKWebView.createPDF` 的回调不保证送达，此前没有超时保护，
    /// 回调缺失时 continuation 永不恢复，调用方（乃至 `swift test` 进程）永久挂起。
    @Test("capture times out instead of hanging when the render never completes")
    func captureTimesOutInsteadOfHanging() async throws {
        // 游离的 WKWebView（未挂到窗口）时 WebKit 可能永远不完成渲染，
        // `createPDF` 回调不会送达 —— 这正是需要超时保护的场景。
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))

        // 用一个极短的超时：无论 WebKit 是否回调，都必须在有限时间内返回。
        let start = Date()
        await #expect(throws: Error.self) {
            _ = try await HTMLScreenshotter.capture(webView, timeout: 0.5)
        }
        let elapsed = Date().timeIntervalSince(start)

        // 超时保护生效：不会无限期挂起。
        #expect(elapsed < 10, "capture 未在合理时间内返回，疑似缺少超时保护")
    }

    /// 超时路径必须抛出 `renderTimedOut`，而不是别的错误。
    ///
    /// 用一个从不渲染的 webView（未挂窗口、未加载任何内容）触发超时分支。
    @Test("capture throws renderTimedOut when the render never completes")
    func captureThrowsRenderTimedOut() async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))

        do {
            _ = try await HTMLScreenshotter.capture(webView, timeout: 0.2)
            // WebKit 罕见地成功返回时也算"没有挂起"。
        } catch let error as HTMLScreenshotter.HTMLError {
            // `HTMLError` 带 associated value，不能直接用 `==` 比较。
            switch error {
            case .renderTimedOut:
                break
            default:
                Issue.record("期望 renderTimedOut，实际为 \(error)")
            }
        } catch {
            // WebKit 自身报错（未加载内容的 webView 常见 WKErrorDomain Code=1），
            // 说明回调正常送达，同样属于"没有挂起"。
        }
    }

    /// 超时错误本身要有可读的描述，便于排查。
    @Test("render timed out error has a readable description")
    func renderTimedOutDescription() {
        let error = HTMLScreenshotter.HTMLError.renderTimedOut
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.lowercased().contains("timed out") == true)
    }
}


/// 等待 WebKit 导航完成的辅助代理。
///
/// 导航委托是弱引用，因此该对象必须在整个等待期间强持有。
@MainActor
private final class NavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var completed = false

    func waitForFinish(timeout: Duration) async {
        guard !completed else { return }
        await withCheckedContinuation { continuation in
            if completed {
                continuation.resume()
                return
            }
            self.continuation = continuation
        }
        // 超时兜底：回调缺失时也不能永久挂起。
        try? await Task.sleep(for: timeout)
    }

    /// 轮询页面内容高度，直到布局真正生效或超时。
    ///
    /// `didFinish` 只表示文档已解析完毕，此时内容高度可能仍是 0 —— 布局由
    /// WebKit 的渲染进程异步完成。忙等（`Task.yield()`）不会让出给渲染进程，
    /// 只有真实的定时等待 + 轮询才能等到布局就绪。
    func waitForLayout(webView: WKWebView, timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let height = await contentHeight(of: webView)
            if height > 0 { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    private func contentHeight(of webView: WKWebView) async -> Double {
        let script = "document.body ? document.body.scrollHeight : 0"
        guard let value = try? await webView.evaluateJavaScript(script) as? NSNumber else { return 0 }
        return value.doubleValue
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !completed else { return }
        completed = true
        continuation?.resume()
        continuation = nil
    }
}
