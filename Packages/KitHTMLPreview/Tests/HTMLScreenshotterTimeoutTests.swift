import AppKit
import Testing
import WebKit

@testable import KitHTMLPreview

/// `HTMLScreenshotter` 的超时保护机制测试（Issue #127）。
///
/// `WKWebView.createPDF` 的完成回调**不保证**送达。若回调缺失而没有超时保护，
/// continuation 永不恢复，调用方（乃至 `swift test` 进程）会永久挂起。
///
/// 这些测试直接针对「一次性完成」状态机，验证其不变量，而不去依赖 WebKit
/// 在不同环境下的具体行为（游离 webView / 窗口内 webView 的表现并不一致）。
@Suite("HTMLScreenshotter 超时保护")
@MainActor
struct HTMLScreenshotterTimeoutTests {

    /// 核心不变量：无论 WebKit 回调与超时任务谁先到，continuation 只能被恢复一次。
    ///
    /// 若这个不变量被破坏（continuation 被恢复两次），Swift 会直接 trap；
    /// 若被破坏成「一次都不恢复」，调用方就永久挂起。
    @Test("PDF 请求状态只会完成一次")
    func pdfRequestStateCompletesOnce() async throws {
        let state = HTMLScreenshotter.PDFRequestState()

        let payload = Data([0x01, 0x02])
        let value = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            state.attach(continuation)

            // 模拟 WebKit 回调与超时任务先后到达（真实情况下顺序不确定）。
            // 第一次 finish 决定结果，后续 finish 必须被忽略。
            state.finish(.success(payload))
            state.finish(.failure(HTMLScreenshotter.HTMLError.renderTimedOut))
            state.finish(.failure(HTMLScreenshotter.HTMLError.pdfCreationFailed))
        }

        // 结果来自第一次 finish；后续 finish 没有覆盖它。
        #expect(state.isCompleted)
        #expect(value == payload)
    }

    /// 未 attach 就 finish 不应崩溃（防御性：状态机不应崩溃）。
    @Test("PDF 请求状态在未挂接 continuation 时也能安全完成")
    func pdfRequestStateFinishesWithoutContinuation() {
        let state = HTMLScreenshotter.PDFRequestState()
        state.finish(.failure(HTMLScreenshotter.HTMLError.renderTimedOut))
        #expect(state.isCompleted)
    }

    /// 超时错误要有可读描述，便于日志与 UI 展示。
    @Test("render timed out error has a readable description")
    func renderTimedOutDescription() {
        let error = HTMLScreenshotter.HTMLError.renderTimedOut
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.errorDescription?.lowercased().contains("timed out") == true)
    }

    /// 既有错误类型的描述不能被这次改动破坏。
    @Test("existing error descriptions are preserved")
    func existingErrorDescriptionsPreserved() {
        #expect(HTMLScreenshotter.HTMLError.pdfCreationFailed.errorDescription?.isEmpty == false)
        #expect(HTMLScreenshotter.HTMLError.emptyDocument.errorDescription?.isEmpty == false)
        #expect(HTMLScreenshotter.HTMLError.renderingFailed("x").errorDescription?.contains("x") == true)
    }
}
