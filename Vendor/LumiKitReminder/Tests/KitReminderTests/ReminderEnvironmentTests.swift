import Foundation
import Testing
@testable import KitReminder

/// SystemReminderEnvironment 的持久化与 token 语义。
///
/// 它直接接触 `UserDefaults.standard`，因此测试统一使用独立的 key 前缀，
/// 避免与真实应用设置互相污染；测试结束后清理。
@MainActor
struct SystemReminderEnvironmentTests {
    private let intervalKey = "KitReminderTests.interval"
    private let customKey = "KitReminderTests.custom"

    private func makeClean() -> SystemReminderEnvironment {
        UserDefaults.standard.removeObject(forKey: intervalKey)
        UserDefaults.standard.removeObject(forKey: customKey)
        return SystemReminderEnvironment()
    }

    @Test("默认无记录时读取间隔返回 0")
    func missingIntervalReadsZero() {
        let env = makeClean()
        #expect(env.savedInterval(forKey: intervalKey) == 0)
    }

    @Test("写入的间隔可被读回")
    func intervalRoundTrips() {
        let env = makeClean()
        env.save(interval: 1800, forKey: intervalKey)
        #expect(env.savedInterval(forKey: intervalKey) == 1800)
        UserDefaults.standard.removeObject(forKey: intervalKey)
    }

    @Test("无记录时自定义间隔返回 nil")
    func missingCustomIntervalsReturnsNil() {
        let env = makeClean()
        #expect(env.savedCustomIntervals(forKey: customKey) == nil)
    }

    @Test("自定义间隔可往返，且空数组不与 nil 混淆")
    func customIntervalsRoundTrip() {
        let env = makeClean()

        env.saveCustomIntervals([], forKey: customKey)
        #expect(env.savedCustomIntervals(forKey: customKey) == [])

        env.saveCustomIntervals([15, 45], forKey: customKey)
        #expect(env.savedCustomIntervals(forKey: customKey) == [15, 45])

        UserDefaults.standard.removeObject(forKey: customKey)
    }

    @Test("now 返回当前时间")
    func nowReturnsCurrentTime() {
        let env = makeClean()
        let before = Date()
        let value = env.now()
        let after = Date()

        #expect(value >= before)
        #expect(value <= after)
    }

    @Test("每次 schedule 返回不同的 token")
    func scheduleReturnsDistinctTokens() {
        let env = makeClean()
        let first = env.schedule(after: 60) {}
        let second = env.schedule(after: 60) {}

        #expect(first != second)
        env.cancel(first)
        env.cancel(second)
    }

    @Test("取消 nil token 是安全的空操作")
    func cancelNilIsNoOp() {
        let env = makeClean()
        env.cancel(nil)
    }

    @Test("overlayPresenter 收到传入的弹层类型")
    func overlayPresenterReceivesKind() {
        var received: [ReminderOverlayKind] = []
        let env = SystemReminderEnvironment { kind in
            received.append(kind)
        }

        env.presentReminderOverlay(kind: .hydration)
        env.presentReminderOverlay(kind: .stretch)

        #expect(received == [.hydration, .stretch])
    }

    @Test("默认实现的 overlayPresenter 不做任何事")
    func defaultOverlayPresenterIsNoOp() {
        let env = SystemReminderEnvironment()
        // 不应崩溃，也不应产生副作用
        env.presentReminderOverlay(kind: .eyeCare)
    }
}

@Suite("ReminderOverlayKind 与 ReminderTimerToken")
struct ReminderValueTypeTests {
    @Test("三种弹层类型的 rawValue 互不重复")
    func overlayKindsAreDistinct() {
        let values = [
            ReminderOverlayKind.eyeCare.rawValue,
            ReminderOverlayKind.hydration.rawValue,
            ReminderOverlayKind.stretch.rawValue,
        ]
        #expect(Set(values).count == 3)
    }

    @Test("弹层类型可由 rawValue 往返构造")
    func overlayKindsRoundTrip() {
        for kind in [ReminderOverlayKind.eyeCare, .hydration, .stretch] {
            #expect(ReminderOverlayKind(rawValue: kind.rawValue) == kind)
        }
    }

    @Test("未知 rawValue 回退为 nil")
    func unknownOverlayKindIsNil() {
        #expect(ReminderOverlayKind(rawValue: "not-a-kind") == nil)
    }

    @Test("相同 id 的 token 视为相等，可用于集合去重")
    func tokensWithSameIDAreEqual() {
        let a = ReminderTimerToken(id: 7)
        let b = ReminderTimerToken(id: 7)
        let c = ReminderTimerToken(id: 8)

        #expect(a == b)
        #expect(a != c)
        #expect(Set([a, b, c]).count == 2)
    }

    @Test("token 暴露其 id")
    func tokenExposesID() {
        #expect(ReminderTimerToken(id: 42).id == 42)
    }
}
