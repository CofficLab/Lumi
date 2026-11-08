import Foundation
import Testing
@testable import KitReminder

/// 计时器回调会真正触发 `Timer`，因此用极短的延迟验证到期行为，
/// 并用引用类型记录器避免并发闭包捕获可变局部变量。
private final class TriggerRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var firedCount = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return firedCount
    }

    func record() {
        lock.lock()
        firedCount += 1
        lock.unlock()
    }
}

@Suite("SystemReminderEnvironment 计时器")
@MainActor
struct SystemReminderEnvironmentTimerTests {
    @Test("计时器到期后回调被触发")
    func timerFiresAfterDelay() async {
        let env = SystemReminderEnvironment()
        let recorder = TriggerRecorder()

        env.schedule(after: 0.05) { recorder.record() }

        try? await Task.sleep(for: .milliseconds(300))
        #expect(recorder.count == 1)
    }

    @Test("取消后的计时器不会触发回调")
    func cancelledTimerNeverFires() async {
        let env = SystemReminderEnvironment()
        let recorder = TriggerRecorder()

        let token = env.schedule(after: 0.05) { recorder.record() }
        env.cancel(token)

        try? await Task.sleep(for: .milliseconds(300))
        #expect(recorder.count == 0)
    }

    @Test("多次排期各自独立触发")
    func multipleTimersFireIndependently() async {
        let env = SystemReminderEnvironment()
        let first = TriggerRecorder()
        let second = TriggerRecorder()

        env.schedule(after: 0.05) { first.record() }
        env.schedule(after: 0.05) { second.record() }

        try? await Task.sleep(for: .milliseconds(300))
        #expect(first.count == 1)
        #expect(second.count == 1)
    }

    @Test("触发过的计时器不再重复触发")
    func timerFiresOnlyOnce() async {
        let env = SystemReminderEnvironment()
        let recorder = TriggerRecorder()

        env.schedule(after: 0.05) { recorder.record() }

        try? await Task.sleep(for: .milliseconds(400))
        #expect(recorder.count == 1)
    }
}
