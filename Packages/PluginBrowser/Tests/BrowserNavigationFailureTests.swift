import Foundation
import Testing
import WebKit
@testable import BrowserPlugin

@Suite("back/forward/reload 导航失败传播", .serialized)
struct BrowserNavigationFailureTests {

    @MainActor
    @Test("back 导航被策略取消时抛出错误而非返回成功")
    func backNavigationCancellationPropagates() async throws {
        let session = BrowserSession(conversationID: UUID())
        let error = NSError(domain: "WebKit", code: -999, userInfo: nil)

        let task = Task { @MainActor in
            try await session.performAndWaitNavigation { }
        }
        await Task.yield()

        session.webView(session.webView, didFailProvisionalNavigation: nil, withError: error)

        do {
            try await task.value
            Issue.record("Expected navigation error to propagate")
        } catch {
            #expect((error as NSError).code == -999)
        }
        session.tearDown()
    }

    @MainActor
    @Test("reload 导航失败时抛出错误而非返回成功")
    func reloadNavigationFailurePropagates() async throws {
        let session = BrowserSession(conversationID: UUID())
        let error = NSError(domain: "WebKit", code: -1009, userInfo: nil)

        let task = Task { @MainActor in
            try await session.performAndWaitNavigation { }
        }
        await Task.yield()

        session.webView(session.webView, didFail: nil, withError: error)

        do {
            try await task.value
            Issue.record("Expected navigation error to propagate")
        } catch {
            #expect((error as NSError).code == -1009)
        }
        session.tearDown()
    }

    @MainActor
    @Test("导航成功时正常返回")
    func successfulNavigationReturns() async throws {
        let session = BrowserSession(conversationID: UUID())

        let task = Task { @MainActor in
            try await session.performAndWaitNavigation { }
        }
        await Task.yield()

        session.webView(session.webView, didFinish: nil)
        try await task.value
        session.tearDown()
    }

    @MainActor
    @Test("本地审批策略取消 back 导航时抛出 blockedLocalNavigation")
    func blockedLocalNavigationPropagates() async throws {
        let session = BrowserSession(conversationID: UUID())

        let task = Task { @MainActor in
            try await session.performAndWaitNavigation { }
        }
        await Task.yield()

        session.webView(session.webView, didFailProvisionalNavigation: nil,
                        withError: BrowserSession.SessionError.blockedLocalNavigation)

        do {
            try await task.value
            Issue.record("Expected blockedLocalNavigation error")
        } catch let error as BrowserSession.SessionError {
            if case .blockedLocalNavigation = error {
                // expected
            } else {
                Issue.record("Expected blockedLocalNavigation, got \(error)")
            }
        }
        session.tearDown()
    }
}