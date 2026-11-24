import Foundation
import Testing
@testable import BrowserPlugin

/// Regression coverage for issue #835: a runtime `document.title` change must
/// reach the cached session title (which backs browser_status and the snapshot
/// header) even when no navigation happens.
@Suite("Browser 会话标题同步")
@MainActor
struct BrowserSessionTitleSyncTests {

    /// 内联加载一个带标题的页面并轮询等待 KVO 同步到位。
    private func loadPage(_ session: BrowserSession, title: String) async throws {
        session.webView.loadHTMLString(
            "<html><head><title>\(title)</title></head><body></body></html>",
            baseURL: nil
        )
        try await waitForTitle(session, equals: title)
    }

    private func waitForTitle(
        _ session: BrowserSession,
        equals expected: String,
        timeout: TimeInterval = 10
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if session.title == expected { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(session.title == expected, "等待标题超时：当前为 \(session.title)")
    }

    @Test("运行时修改 document.title 后会话标题立即跟随")
    func runtimeTitleChangeIsReflected() async throws {
        let session = BrowserSession(conversationID: UUID())
        defer { session.tearDown() }

        try await loadPage(session, title: "Original")
        #expect(session.title == "Original")

        _ = try await session.webView.evaluateJavaScript("document.title = 'Changed'")
        try await waitForTitle(session, equals: "Changed")
        #expect(session.title == "Changed")
    }
}
