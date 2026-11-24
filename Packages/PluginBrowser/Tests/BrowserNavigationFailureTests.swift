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
            try await session.performAndWaitNavigation { nil }
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
            try await session.performAndWaitNavigation { nil }
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
            try await session.performAndWaitNavigation { nil }
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
            try await session.performAndWaitNavigation { nil }
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

    /// 回归 #264：旧导航的迟到失败回调携带的是旧 WKNavigation 实例，
    /// 不得结束当前（新）导航。
    ///
    /// 注意：实例必须取自真实 `load` 的返回值——直接 `WKNavigation()`
    /// 构造会让整个测试进程在退出时崩溃。
    @MainActor
    @Test("旧导航的迟到失败回调不会失败新导航")
    func staleDidFailIsIgnoredForNewerNavigation() async throws {
        let session = BrowserSession(conversationID: UUID())
        let blankURL = URL(string: "about:blank")!
        // 旧导航 A：发起后立刻停掉，它的实例稍后以迟到回调的形式出现。
        let staleNavigation = try #require(session.webView.load(URLRequest(url: blankURL)))
        session.webView.stopLoading()

        let task = Task { @MainActor in
            try await session.performAndWaitNavigation {
                session.webView.load(URLRequest(url: blankURL))
            }
        }
        for _ in 0..<100 where !session.isLoading { await Task.yield() }
        try #require(session.isLoading)

        // 旧导航 A 的迟到失败回调：必须被忽略，新导航 B 由它的真实
        // didFinish 正常完成。
        session.webView(session.webView, didFail: staleNavigation,
                        withError: NSError(domain: "WebKit", code: -999, userInfo: nil))

        try await task.value
        session.tearDown()
    }

    /// 回归 #264：旧导航的迟到 didFinish 不得提前完成新导航，
    /// 新导航随后的失败必须照常传播。
    @MainActor
    @Test("旧导航的迟到完成回调不会提前完成新导航")
    func staleDidFinishDoesNotCompleteNewerNavigation() async throws {
        let session = BrowserSession(conversationID: UUID())
        let blankURL = URL(string: "about:blank")!
        let staleNavigation = try #require(session.webView.load(URLRequest(url: blankURL)))
        session.webView.stopLoading()

        let box = NavigationBox()
        let task = Task { @MainActor in
            try await session.performAndWaitNavigation {
                let navigation = session.webView.load(URLRequest(url: blankURL))
                box.value = navigation
                return navigation
            }
        }
        for _ in 0..<100 where !session.isLoading { await Task.yield() }
        try #require(session.isLoading)
        let currentNavigation = try #require(box.value)

        // 旧导航 A 的迟到 didFinish：不得提前结束 B。
        session.webView(session.webView, didFinish: staleNavigation)
        // B 自己的失败回调（携带 B 的实例）必须照常传播。
        session.webView(session.webView, didFail: currentNavigation,
                        withError: NSError(domain: "WebKit", code: -1009, userInfo: nil))

        do {
            try await task.value
            Issue.record("Expected the newer navigation to fail after the stale didFinish was ignored")
        } catch {
            #expect((error as NSError).code == -1009)
        }
        session.tearDown()
    }
}

@MainActor
private final class NavigationBox {
    var value: WKNavigation?
}