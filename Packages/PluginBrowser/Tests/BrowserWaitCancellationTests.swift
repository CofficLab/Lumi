import Foundation
import Testing
@testable import BrowserPlugin

/// `browser_wait` 的取消行为（见 issue #418）。
///
/// 等待循环原先用 `try?` 吞掉 `Task.sleep` 的取消错误：任务被取消后
/// sleep 立即抛错返回，吞掉它会让循环立刻进入下一轮 ——
/// load / navigation 这类不需要 JS await 的分支变成主线程忙轮询，
/// 而且要一直空转到超时才结束。
@Suite("browser_wait 取消行为")
struct BrowserWaitCancellationTests {

    private func makeLoop(timeout: TimeInterval = 60) -> BrowserWaitLoop {
        BrowserWaitLoop(
            pollInterval: 0.15,
            deadline: Date().addingTimeInterval(timeout)
        )
    }

    @Test("取消后立刻抛出 CancellationError")
    func cancellationThrowsImmediately() async {
        let loop = makeLoop()

        let task = Task {
            try await loop.run(isSatisfied: { false })
        }

        // 让循环跑起来。
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected CancellationError")
        } catch is CancellationError {
            // 预期：取消立刻向上传播。
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }
    }

    @Test("取消后不再继续轮询")
    func cancellationStopsPolling() async {
        let loop = makeLoop()

        let counter = PollCounter()
        let task = Task {
            try await loop.run(isSatisfied: {
                await counter.increment()
                return false
            })
        }

        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        _ = try? await task.value

        let countAtCancel = await counter.value
        // 再等一会儿，确认计数不再增长。
        try? await Task.sleep(for: .milliseconds(400))
        let countAfter = await counter.value

        #expect(countAtCancel > 0)
        #expect(countAfter == countAtCancel)
    }

    @Test("条件成立时正常返回")
    func satisfiedConditionReturns() async throws {
        let loop = BrowserWaitLoop(
            pollInterval: 0.01,
            deadline: Date().addingTimeInterval(5)
        )

        let satisfied = try await loop.run(isSatisfied: { true })
        #expect(satisfied)
    }

    @Test("超时返回 false")
    func timeoutReturnsFalse() async throws {
        let loop = BrowserWaitLoop(
            pollInterval: 0.01,
            deadline: Date().addingTimeInterval(0.05)
        )

        let satisfied = try await loop.run(isSatisfied: { false })
        #expect(satisfied == false)
    }
}

/// 轮询计数器。
private actor PollCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
