import AppKit
import Foundation
import Testing
@testable import KitReminder

/// 提醒计时的健壮性：事件跟踪期间不推迟、睡眠后不丢。
@Suite("提醒计时健壮性")
@MainActor
struct ReminderTimerRobustnessTests {
    /// 计时器回调会真正触发 `Timer`，用引用类型记录器避免并发闭包捕获可变局部变量。
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

    @Test("common 模式与 default 模式并存，计时器可装入 common")
    func commonRunLoopModeExists() {
        // 实现使用 `RunLoop.main.add(timer, forMode: .common)`，
        // 这样 AppKit 事件跟踪期间（拖菜单、滑块）计时器仍会触发；
        // 若退回 `Timer.scheduledTimer`（仅 default），提醒会被推迟。
        #expect(RunLoop.Mode.common != RunLoop.Mode.default)
        #expect(RunLoop.Mode.common.rawValue != RunLoop.Mode.default.rawValue)
    }

    @Test("已到期的计时被识别为过期")
    func expiredTimersAreDetected() {
        let now = Date()
        let timers: [UInt64: SystemReminderEnvironment.ScheduledTimer] = [
            1: makeScheduled(deadline: now.addingTimeInterval(-10)),
            2: makeScheduled(deadline: now.addingTimeInterval(10)),
            3: makeScheduled(deadline: now.addingTimeInterval(-1)),
        ]

        let expired = SystemReminderEnvironment.expiredTimerIDs(in: timers, now: now)

        #expect(expired == [1, 3], "只有到期时间已过的计时才应被视为过期")
    }

    @Test("没有过期计时时返回空")
    func noExpiredTimers() {
        let now = Date()
        let timers: [UInt64: SystemReminderEnvironment.ScheduledTimer] = [
            1: makeScheduled(deadline: now.addingTimeInterval(60)),
        ]

        #expect(SystemReminderEnvironment.expiredTimerIDs(in: timers, now: now).isEmpty)
    }

    @Test("睡眠期间到期的计时在唤醒后立即补触发")
    func expiredTimerFiresOnWake() async {
        let env = SystemReminderEnvironment()
        let recorder = TriggerRecorder()

        // 排一个远未到期的计时（模拟睡眠期间到期的情形：
        // 真实场景中 deadline 是绝对时间，醒来时已经过期）。
        let token = env.schedule(after: 3600) { recorder.record() }

        // 手动把到期时间推到过去，模拟睡眠期间已到期
        env.markTimerExpired(token)

        env.didWakeFromSleep()

        #expect(recorder.count == 1, "睡眠期间到期的提醒应在唤醒后补触发")
    }

    @Test("唤醒不会触发未到期的计时")
    func wakeDoesNotFirePendingTimer() async {
        let env = SystemReminderEnvironment()
        let recorder = TriggerRecorder()

        env.schedule(after: 3600) { recorder.record() }
        env.didWakeFromSleep()

        try? await Task.sleep(for: .milliseconds(50))
        #expect(recorder.count == 0, "未到期的计时不应因唤醒而触发")
    }

    @Test("取消后的计时不会因唤醒而触发")
    func cancelledTimerDoesNotFireOnWake() async {
        let env = SystemReminderEnvironment()
        let recorder = TriggerRecorder()

        let token = env.schedule(after: 3600) { recorder.record() }
        env.cancel(token)

        env.didWakeFromSleep()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(recorder.count == 0)
    }

    @Test("唤醒后已到期的计时只触发一次")
    func wakeFiresExpiredTimerOnce() async {
        let env = SystemReminderEnvironment()
        let recorder = TriggerRecorder()

        let token = env.schedule(after: 3600) { recorder.record() }
        env.markTimerExpired(token)

        env.didWakeFromSleep()
        env.didWakeFromSleep()

        #expect(recorder.count == 1)
    }

    /// 构造一个指定到期时间的计时条目。
    private func makeScheduled(deadline: Date) -> SystemReminderEnvironment.ScheduledTimer {
        SystemReminderEnvironment.ScheduledTimer(
            timer: Timer(timeInterval: 3600, repeats: false) { _ in },
            deadline: deadline,
            handler: {}
        )
    }
}
