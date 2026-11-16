import Testing
import Foundation
@testable import KitShell

/// Regression for #171: the readability callback and the terminationHandler of
/// `executeStreaming` run concurrently. The stdout handler calls the external
/// `onOutputData(data)` *before* `stdoutBuffer.append(data)`, and the termination
/// path used to clear the handlers, drain and `state.complete` without waiting
/// for an already-started callback. A slow consumer therefore let the function
/// return with `stdout == ""` while the blocked callback later appended the data,
/// and the callback crossed the return boundary into state the caller had reset.
///
/// Each test keeps the process alive briefly after it writes (`sleep 0.2`) so the
/// readability callback is provably in flight when the process exits, then makes
/// that callback slow (`Thread.sleep`/gate) to reproduce the race deterministically.
@Suite(.serialized)
struct ShellStreamingCallbackRaceTests {

    @Test("慢速 onOutputData 不得让聚合 stdout 丢失已读数据，回调不得跨越返回边界（#171）")
    func slowOutputDataCallbackDoesNotDropAggregatedStdout() async throws {
        let callbackDone = LockedFlag()
        let result = try await ShellExecutor.executeStreaming(
            "printf hello; sleep 0.2",
            onOutput: { _ in },
            onOutputData: { _ in
                // Slow consumer: outlives the process exit at 0.2s.
                Thread.sleep(forTimeInterval: 0.5)
                callbackDone.set()
            }
        )

        // The fix waits for the in-flight callback before completing, so it must
        // already be done when executeStreaming returns.
        #expect(callbackDone.value, "输出回调不得跨越 executeStreaming 的返回边界（#171）")
        #expect(result.stdout == "hello", "慢速回调不得让聚合 stdout 丢失已读数据（#171）")
    }

    @Test("慢速 onErrorData 不得让聚合 stderr 丢失已读数据，回调不得跨越返回边界（#171）")
    func slowErrorDataCallbackDoesNotDropAggregatedStderr() async throws {
        let callbackDone = LockedFlag()
        let result = try await ShellExecutor.executeStreaming(
            "printf hello >&2; sleep 0.2",
            onOutput: { _ in },
            onError: { _ in },
            onErrorData: { _ in
                Thread.sleep(forTimeInterval: 0.5)
                callbackDone.set()
            }
        )

        #expect(callbackDone.value, "stderr 回调不得跨越 executeStreaming 的返回边界（#171）")
        #expect(result.stderr == "hello", "慢速 stderr 回调不得让聚合 stderr 丢失已读数据（#171）")
    }

    @Test("输出回调被阻塞时 executeStreaming 不得提前产生结果（#171）")
    func executeStreamingDoesNotReturnWhileOutputCallbackIsBlocked() async throws {
        let started = OneShotSignal()
        let release = DispatchSemaphore(value: 0)
        let resultBox = LockedBox<ShellResult>()
        let callbackDone = LockedFlag()

        let task = Task { () -> ShellResult in
            let result = try await ShellExecutor.executeStreaming(
                "printf hello; sleep 0.2",
                onOutput: { _ in },
                onOutputData: { _ in
                    started.fire()
                    // Block this background callback until the test releases it.
                    release.wait()
                    callbackDone.set()
                }
            )
            resultBox.set(result)
            return result
        }

        // Wait until the callback is genuinely in flight and blocked; the process
        // then exits at 0.2s and the termination path reaches the wait point.
        await started.wait()
        try await Task.sleep(for: .milliseconds(600))

        // With the fix the termination handler waits for the blocked callback, so
        // no result may exist yet. Without it the function returns early here.
        #expect(resultBox.value == nil, "回调仍在阻塞时不得提前产生结果（#171）")

        release.signal()
        let result = try await task.value
        #expect(callbackDone.value, "回调必须在返回前完成（#171）")
        #expect(result.stdout == "hello", "释放回调后聚合 stdout 必须包含已读数据（#171）")
    }
}

// MARK: - Thread-safe test helpers

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    func set() {
        lock.lock()
        flag = true
        lock.unlock()
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }
}

private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: T?

    func set(_ value: T) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    var value: T? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// A one-shot latch: `fire()` may happen before or after `wait()`; the waiter
/// resumes exactly once. Used to observe the callback entering its blocked state
/// from the async test body without blocking a cooperative thread.
private final class OneShotSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    private var continuation: CheckedContinuation<Void, Never>?

    func fire() {
        lock.lock()
        if fired {
            lock.unlock()
            return
        }
        fired = true
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume()
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if fired {
                lock.unlock()
                continuation.resume()
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }
}