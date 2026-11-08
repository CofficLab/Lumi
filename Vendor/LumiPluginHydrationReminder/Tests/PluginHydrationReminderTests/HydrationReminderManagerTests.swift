import Foundation
import KitReminder
import Testing
@testable import PluginHydrationReminder

/// 可控的时间 / 持久化 / 计时替身。
///
/// `HydrationReminderManager` 改造后不再直接调用 `Date()`、`UserDefaults.standard`
/// 与 `Timer.scheduledTimer`，因此测试可以：
/// - 精确断言 `nextBreakTime` 的计算结果，而不必 sleep
/// - 直接触发计时回调，覆盖原本无法触达的 `fireBreakReminder`
/// - 避免创建真实 NSWindow 弹层（无窗口进程会 signal 5）
@MainActor
final class FakeReminderEnvironment: ReminderEnvironment {
    /// 基准时间：固定值，避免依赖真实时钟导致断言抖动
    private(set) var currentTime: Date
    /// 已持久化的间隔
    private(set) var storedIntervals: [String: TimeInterval] = [:]
    /// 已持久化的自定义间隔（分钟）
    private(set) var storedCustomIntervals: [String: [Int]] = [:]

    /// 尚未触发的计时：(token, 触发时刻, 回调)
    private(set) var pendingTimers: [(token: ReminderTimerToken, fireAt: Date, handler: () -> Void)] = []
    /// 已展示的弹层类型序列
    private(set) var presentedOverlays: [ReminderOverlayKind] = []
    /// 被取消的 token 数量
    private(set) var cancelledCount = 0

    private var nextToken: UInt64 = 0

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.currentTime = now
    }

    /// 预置持久化数据，模拟「应用上次退出时保存的设置」。
    func seed(interval: TimeInterval? = nil, customIntervals: [Int]? = nil) {
        if let interval { storedIntervals["HydrationReminderInterval"] = interval }
        if let customIntervals { storedCustomIntervals["HydrationCustomIntervals"] = customIntervals }
    }

    // MARK: - ReminderEnvironment

    func now() -> Date { currentTime }

    func savedInterval(forKey key: String) -> TimeInterval { storedIntervals[key] ?? 0 }

    func save(interval: TimeInterval, forKey key: String) {
        storedIntervals[key] = interval
    }

    func savedCustomIntervals(forKey key: String) -> [Int]? { storedCustomIntervals[key] }

    func saveCustomIntervals(_ minutes: [Int], forKey key: String) {
        storedCustomIntervals[key] = minutes
    }

    func schedule(after delay: TimeInterval, handler: @escaping () -> Void) -> ReminderTimerToken {
        nextToken += 1
        let token = ReminderTimerToken(id: nextToken)
        pendingTimers.append((token, currentTime.addingTimeInterval(delay), handler))
        return token
    }

    func cancel(_ token: ReminderTimerToken?) {
        guard let token else { return }
        cancelledCount += 1
        pendingTimers.removeAll { $0.token == token }
    }

    func presentReminderOverlay(kind: ReminderOverlayKind) {
        presentedOverlays.append(kind)
    }

    /// 状态存储：测试用内存实现，不落盘。
    var stateStore: ReminderStateStore = .inMemory()

    /// 状态存储目录（测试用临时目录）。
    let stateStoreDirectory: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ReminderState-\(UUID().uuidString)", isDirectory: true)

    func attachStateStore(directory: URL) {
        stateStore = ReminderStateStore(directory: directory)
    }

    /// 已持久化的「运行中」状态。
    var storedActiveStates: [String: Bool] = [:]

    func savedActiveState(forKey key: String) -> Bool {
        storedActiveStates[key] ?? false
    }

    func saveActiveState(_ isActive: Bool, forKey key: String) {
        storedActiveStates[key] = isActive
    }

    // MARK: - 测试控制

    /// 模拟系统从睡眠中唤醒。
    ///
    /// 睡眠期间计时器不会触发，但时间仍在流逝；醒来后已到期的计时
    /// 应立即补触发（否则「稍后提醒」的意图会丢失）。
    func simulateWakeFromSleep(afterSleeping seconds: TimeInterval) {
        advance(by: seconds)
    }

    /// 推进虚拟时钟，并触发所有到期回调。
    func advance(by seconds: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(seconds)
        // 循环触发：一次推进可能让回调重新排期（如提醒后自动排下一次）
        var guardCounter = 0
        while guardCounter < 100 {
            let due = pendingTimers.filter { $0.fireAt <= currentTime }
            guard let next = due.first else { break }
            pendingTimers.removeAll { $0.token == next.token }
            next.handler()
            guardCounter += 1
        }
    }

    /// 当前待触发计时对应的下次提醒时刻
    var nextFireTime: Date? { pendingTimers.map(\.fireAt).min() }
}

@Suite("HydrationReminderManager 生命周期")
@MainActor
struct HydrationReminderManagerLifecycleTests {
    @Test("初始状态未激活且无下次提醒")
    func startsInactive() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)

        #expect(!manager.isActive)
        #expect(manager.nextBreakTime == nil)
        #expect(manager.startTime == nil)
        #expect(manager.timeUntilNextBreak() == nil)
    }

    @Test("start 激活并按选中间隔排定下次提醒")
    func startSchedulesNextBreak() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        #expect(manager.selectedInterval == 7200)

        manager.start()

        #expect(manager.isActive)
        #expect(manager.startTime == env.currentTime)
        #expect(manager.nextBreakTime == env.currentTime.addingTimeInterval(7200))
        #expect(manager.timeUntilNextBreak() == 7200)
        #expect(env.pendingTimers.count == 1)
    }

    @Test("重复 start 不会重复排期")
    func startIsIdempotent() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()
        let firstFire = env.nextFireTime

        manager.start()

        #expect(env.pendingTimers.count == 1, "第二次 start 不应新增计时")
        #expect(env.nextFireTime == firstFire)
    }

    @Test("stop 清空激活态与排期")
    func stopClearsState() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        manager.stop()

        #expect(!manager.isActive)
        #expect(manager.nextBreakTime == nil)
        #expect(manager.startTime == nil)
        #expect(manager.timeUntilNextBreak() == nil)
        #expect(env.pendingTimers.isEmpty, "stop 必须取消尚未触发的计时")
    }

    @Test("未激活时 stop 是安全的空操作")
    func stopWithoutStartIsNoOp() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)

        manager.stop()

        #expect(!manager.isActive)
        #expect(env.cancelledCount == 0, "空操作不应产生取消动作")
    }

    @Test("stop 后可重新 start 并使用新的当前时间")
    func restartAfterStop() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()
        manager.stop()

        env.advance(by: 500)
        manager.start()

        #expect(manager.isActive)
        #expect(manager.startTime == env.currentTime)
        #expect(manager.nextBreakTime == env.currentTime.addingTimeInterval(7200))
    }
}

@Suite("HydrationReminderManager 提醒触发")
@MainActor
struct HydrationReminderManagerFiringTests {
    @Test("到达间隔时展示弹层并累计次数")
    func firesOverlayAndCounts() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        env.advance(by: 7200)

        #expect(manager.todayBreakCount == 1)
        #expect(env.presentedOverlays == [.hydration])
    }

    @Test("提醒后自动排定下一次，不需手动重启")
    func reschedulesAfterFiring() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()
        let firstFire = env.nextFireTime

        env.advance(by: 7200)

        #expect(env.nextFireTime != firstFire, "应排定新的下次提醒")
        #expect(env.nextFireTime == env.currentTime.addingTimeInterval(7200))
        #expect(manager.nextBreakTime == env.nextFireTime)
    }

    @Test("连续触发多次正确累加次数")
    func accumulatesAcrossCycles() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        env.advance(by: 7200)
        env.advance(by: 7200)
        env.advance(by: 7200)

        #expect(manager.todayBreakCount == 3)
        #expect(env.presentedOverlays.count == 3)
    }

    @Test("stop 之后到期的回调不再计数")
    func stoppedManagerIgnoresFiring() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        // 取消计时后手动重放一个已到期的回调，模拟竞态
        let staleHandler = env.pendingTimers.first?.handler
        manager.stop()
        staleHandler?()

        #expect(manager.todayBreakCount == 0)
        #expect(env.presentedOverlays.isEmpty)
    }

    @Test("snooze 把下次提醒推迟到指定分钟之后")
    func snoozePushesNextBreak() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        manager.snooze(minutes: 5)

        #expect(manager.nextBreakTime == env.currentTime.addingTimeInterval(300))
        #expect(env.nextFireTime == env.currentTime.addingTimeInterval(300))
    }

    @Test("未激活时 snooze 不排期")
    func snoozeWhileInactiveIsNoOp() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)

        manager.snooze(minutes: 5)

        #expect(manager.nextBreakTime == nil)
        #expect(env.pendingTimers.isEmpty)
    }

    @Test("snooze 覆盖原有排期")
    func snoozeReplacesPreviousSchedule() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        manager.snooze(minutes: 10)

        #expect(env.pendingTimers.count == 1, "snooze 应替换而非叠加计时")
        #expect(env.nextFireTime == env.currentTime.addingTimeInterval(600))
    }
    @Test("snooze 期间若发生睡眠，醒来后仍会补提醒")
    func snoozeSurvivesSleep() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        // 用户点了「稍后提醒 5 分钟」
        manager.snooze(minutes: 5)

        // 期间系统睡眠了 10 分钟——醒来时早已过 snooze 的到期时间
        env.simulateWakeFromSleep(afterSleeping: 600)

        #expect(
            env.presentedOverlays == [.hydration],
            "用户明确要求的稍后提醒，不应因睡眠而丢失"
        )
    }

}

@Suite("HydrationReminderManager 间隔调整")
@MainActor
struct HydrationReminderManagerIntervalTests {
    @Test("更新间隔会持久化并在激活时重排")
    func updateIntervalPersistsAndReschedules() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        manager.updateInterval(1800)

        #expect(manager.selectedInterval == 1800)
        #expect(env.storedIntervals["HydrationReminderInterval"] == 1800)
        #expect(manager.nextBreakTime == env.currentTime.addingTimeInterval(1800))
    }

    @Test("未激活时更新间隔不影响排期")
    func updateIntervalWhileInactiveDoesNotSchedule() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)

        manager.updateInterval(1800)

        #expect(manager.selectedInterval == 1800)
        #expect(env.pendingTimers.isEmpty)
    }

    @Test("新增自定义间隔会插入排序并自动选中")
    func addCustomIntervalInsertsSorted() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)

        manager.addCustomInterval(minutes: 45)

        #expect(manager.availableIntervals.contains(.minutes(45)))
        #expect(manager.selectedInterval == 2700, "新增间隔应自动选中")
        let times = manager.availableIntervals.map(\.timeInterval)
        #expect(times == times.sorted(), "间隔列表应保持升序")
    }

    @Test("重复新增同一间隔不会产生重复项")
    func addCustomIntervalIsDeduplicated() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.addCustomInterval(minutes: 45)
        let count = manager.availableIntervals.count

        manager.addCustomInterval(minutes: 45)

        #expect(manager.availableIntervals.count == count)
    }

    @Test("新增与预设等长的自定义间隔不会并存")
    func addCustomIntervalMatchingPresetDoesNotDuplicate() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)

        // 60 分钟与预设「1 小时」是同一时长
        manager.addCustomInterval(minutes: 60)

        let seconds = manager.availableIntervals.map(\.timeInterval)
        #expect(Set(seconds).count == seconds.count, "同一时长不应出现两次，否则选择器会渲染出两个同时高亮的按钮")
        #expect(!manager.availableIntervals.contains(.minutes(60)))
    }

    @Test("间隔列表中不存在重复时长")
    func availableIntervalsHaveNoDuplicateDurations() {
        let env = FakeReminderEnvironment()
        env.seed(customIntervals: [20, 45, 60, 120])
        let manager = HydrationReminderManager(environment: env)

        let seconds = manager.availableIntervals.map(\.timeInterval)
        #expect(Set(seconds).count == seconds.count)
        #expect(seconds == seconds.sorted(), "间隔列表应保持升序")
    }

    @Test("移除默认间隔被忽略")
    func cannotRemoveDefaultInterval() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        let before = manager.availableIntervals

        manager.removeInterval(.minutes(30))

        #expect(manager.availableIntervals == before)
    }

    @Test("移除当前选中的自定义间隔会回退到默认间隔")
    func removingSelectedCustomIntervalFallsBack() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.addCustomInterval(minutes: 45)
        #expect(manager.selectedInterval == 2700)

        manager.removeInterval(.minutes(45))

        #expect(!manager.availableIntervals.contains(.minutes(45)))
        #expect(manager.selectedInterval == HydrationReminderManager.defaultInterval.timeInterval)
    }

    @Test("移除未选中的自定义间隔不改变选中值")
    func removingOtherIntervalKeepsSelection() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.addCustomInterval(minutes: 45)
        manager.addCustomInterval(minutes: 20)
        let selected = manager.selectedInterval

        manager.removeInterval(.minutes(45))

        #expect(!manager.availableIntervals.contains(.minutes(45)))
        #expect(manager.selectedInterval == selected)
    }

    @Test("重置恢复默认间隔并选中默认间隔")
    func resetRestoresDefaults() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.addCustomInterval(minutes: 45)

        manager.resetIntervals()

        #expect(manager.availableIntervals == HydrationReminderManager.commonIntervals)
        #expect(manager.selectedInterval == HydrationReminderManager.defaultInterval.timeInterval)
    }
}

@Suite("HydrationReminderManager 持久化")
@MainActor
struct HydrationReminderManagerPersistenceTests {
    @Test("构造时读取已持久化的间隔")
    func loadsPersistedInterval() {
        let env = FakeReminderEnvironment()
        env.seed(interval: 2700)

        let manager = HydrationReminderManager(environment: env)

        #expect(manager.selectedInterval == 2700)
    }

    @Test("无持久化记录时使用默认 2 小时")
    func fallsBackToDefaultInterval() {
        let env = FakeReminderEnvironment()

        let manager = HydrationReminderManager(environment: env)

        #expect(manager.selectedInterval == 7200)
    }

    @Test("构造时读取已持久化的自定义间隔")
    func loadsPersistedCustomIntervals() {
        let env = FakeReminderEnvironment()
        env.seed(customIntervals: [45, 20])

        let manager = HydrationReminderManager(environment: env)

        #expect(manager.availableIntervals.contains(.minutes(45)))
        #expect(manager.availableIntervals.contains(.minutes(20)))
        let times = manager.availableIntervals.map(\.timeInterval)
        #expect(times == times.sorted(), "合并自定义间隔后仍应保持升序")
    }

    @Test("自定义间隔与默认重复时不产生重复项")
    func customIntervalsDeduplicateDefaults() {
        let env = FakeReminderEnvironment()
        // 30 分钟已是默认间隔
        env.seed(customIntervals: [30])

        let manager = HydrationReminderManager(environment: env)

        let count = manager.availableIntervals.filter { $0 == .minutes(30) }.count
        #expect(count == 1, "与默认重复的自定义间隔应被忽略")
    }

    @Test("保存自定义间隔只写入非默认项")
    func savesOnlyNonDefaultIntervals() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.addCustomInterval(minutes: 45)

        let saved = env.storedCustomIntervals["HydrationCustomIntervals"]
        #expect(saved == [45], "只应持久化自定义间隔，实际: \(String(describing: saved))")
    }

    @Test("自定义间隔持久化后可被新实例读回")
    func customIntervalsSurviveReload() {
        let env = FakeReminderEnvironment()
        let first = HydrationReminderManager(environment: env)
        first.addCustomInterval(minutes: 45)

        // 用同一个 env 构造新实例，模拟应用重启
        let reloaded = HydrationReminderManager(environment: env)

        #expect(reloaded.availableIntervals.contains(.minutes(45)))
    }
}

@Suite("HydrationReminderManager 权限与清理")
@MainActor
struct HydrationReminderManagerMiscTests {


    @Test("cleanup 取消待触发计时")
    func cleanupCancelsTimers() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        manager.cleanup()

        #expect(env.pendingTimers.isEmpty)
    }
}

@Suite("HydrationReminderManager 今日计数")
@MainActor
struct HydrationReminderManagerTodayCountTests {
    @Test("触发提醒后今日计数递增")
    func countIncrementsOnFiring() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        env.advance(by: HydrationReminderManager.defaultInterval.timeInterval)

        #expect(manager.todayBreakCount == 1)
    }

    @Test("重启后今日计数保留")
    func countSurvivesRestart() {
        let env = FakeReminderEnvironment()
        let first = HydrationReminderManager(environment: env)
        first.start()
        env.advance(by: HydrationReminderManager.defaultInterval.timeInterval)
        #expect(first.todayBreakCount == 1)

        // 模拟重启：新建 manager，共享同一个状态存储
        let reloaded = HydrationReminderManager(environment: env)

        #expect(reloaded.todayBreakCount == 1, "重启后今日计数应保留")
    }
}

@Suite("HydrationReminderManager 运行态持久化")
@MainActor
struct HydrationReminderManagerActiveStateTests {
    @Test("start 后运行态被持久化")
    func startPersistsActiveState() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)

        manager.start()

        #expect(
            env.storedActiveStates.values.contains(true),
            "开启提醒后应记录运行态，以便重启后恢复"
        )
    }

    @Test("stop 后运行态被清除")
    func stopClearsActiveState() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)
        manager.start()

        manager.stop()

        #expect(
            env.storedActiveStates.values.contains(false),
            "关闭提醒后应清除运行态"
        )
    }

    @Test("重启后提醒恢复运行")
    func restoresRunningStateAfterRelaunch() {
        // 第一次运行：用户开启提醒
        let env = FakeReminderEnvironment()
        let first = HydrationReminderManager(environment: env)
        first.start()
        #expect(first.isActive)

        // 模拟重启：新建 manager，共享同一个状态存储
        let relaunched = HydrationReminderManager(environment: env)
        relaunched.attachStateStore(directory: env.stateStoreDirectory)

        #expect(
            relaunched.isActive,
            "重启后提醒应继续工作，否则会静默失效"
        )
        #expect(relaunched.nextBreakTime != nil, "恢复后应重新排定下一次提醒")
    }

    @Test("重启前未开启提醒则不恢复")
    func doesNotRestoreWhenNeverStarted() {
        let env = FakeReminderEnvironment()
        let manager = HydrationReminderManager(environment: env)

        manager.attachStateStore(directory: env.stateStoreDirectory)

        #expect(!manager.isActive, "首次启动不应自动开启提醒")
    }
}
