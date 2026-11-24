import Foundation
import Testing
import WebKit
@testable import KitHTMLPreview

/// #430：已取消的截图必须立即以 CancellationError 中止，
/// 不得发起 createPDF 渲染或空等超时。
@Suite("HTMLScreenshotter 取消传播")
@MainActor
struct HTMLScreenshotterCancellationTests {
    @Test("已取消的任务在发起渲染前立即中止")
    func cancelledCaptureAbortsBeforeRendering() async {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let task = Task {
            try await HTMLScreenshotter.capture(webView)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
