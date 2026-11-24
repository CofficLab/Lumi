import Foundation
import Testing
@testable import BrowserPlugin

/// 回归 #419：导航使用的 checked continuation 没有取消处理——任务被取消后
/// 既不停止 WebKit 加载，也不结束 continuation，调用方只能干等 30 秒超时。
/// 取消必须立刻走 stop() 路径：停止加载、结束 continuation、向上抛
/// navigationCancelled。
@Suite("导航任务取消", .serialized)
struct BrowserNavigationCancellationTests {

    @MainActor
    @Test("挂起的导航任务被取消时立刻停止加载并抛出 navigationCancelled")
    func cancelledPerformAndWaitThrowsPromptly() async throws {
        let session = BrowserSession(conversationID: UUID())
        let task = Task { @MainActor in
            try await session.performAndWaitNavigation { nil }
        }
        for _ in 0..<100 where !session.isLoading { await Task.yield() }
        try #require(session.isLoading)

        task.cancel()
        do {
            try await task.value
            Issue.record("Expected navigationCancelled")
        } catch {
            if case .navigationCancelled = error as? BrowserSession.SessionError {
                // expected
            } else {
                Issue.record("Expected navigationCancelled, got \(error)")
            }
        }
        #expect(!session.isLoading, "取消后加载状态必须复位")
        session.tearDown()
    }

    @MainActor
    @Test("navigate 的任务被取消时立刻停止加载并抛出 navigationCancelled")
    func cancelledNavigateStopsLoadAndThrows() async throws {
        let session = BrowserSession(conversationID: UUID())
        let task = Task { @MainActor in
            try await session.navigate(to: URL(string: "about:blank")!)
        }
        for _ in 0..<100 where !session.isLoading { await Task.yield() }
        try #require(session.isLoading)

        task.cancel()
        do {
            try await task.value
            Issue.record("Expected navigationCancelled")
        } catch {
            if case .navigationCancelled = error as? BrowserSession.SessionError {
                // expected
            } else {
                Issue.record("Expected navigationCancelled, got \(error)")
            }
        }
        #expect(!session.isLoading, "取消后加载状态必须复位")
        session.tearDown()
    }

    @MainActor
    @Test("任务已取消时不再发起新导航")
    func precancelledNavigateFailsImmediately() async throws {
        let session = BrowserSession(conversationID: UUID())
        let task = Task { @MainActor in
            try await session.navigate(to: URL(string: "about:blank")!)
        }
        // 同一主 actor 轮次内同步取消：任务体尚未启动，必须在入口处失败。
        task.cancel()
        do {
            try await task.value
            Issue.record("Expected CancellationError")
        } catch {
            #expect(error is CancellationError, "Expected CancellationError, got \(error)")
        }
        #expect(!session.isLoading)
        session.tearDown()
    }
}
