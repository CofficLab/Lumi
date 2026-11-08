import Foundation
import Testing
@testable import KitReminder

/// 「今日次数」计数器的跨日归零与持久化行为。
@Suite("DailyCounter 每日计数")
struct DailyCounterTests {
    /// 可推进的测试时钟。
    ///
    /// 用引用类型承载可变时间，避免 `@Sendable` 闭包捕获可变变量。
    private final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Date

        init(_ date: Date) {
            current = date
        }

        var now: Date {
            lock.lock()
            defer { lock.unlock() }
            return current
        }

        func advance(by seconds: TimeInterval) {
            lock.lock()
            current = current.addingTimeInterval(seconds)
            lock.unlock()
        }
    }

    private func makeStore() -> ReminderStateStore {
        .inMemory()
    }

    @Test("初始计数为 0")
    func startsAtZero() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let counter = DailyCounter(
            store: makeStore(),
            keyPrefix: "test",
            dayProvider: { clock.now }
        )

        #expect(counter.todayCount == 0)
    }

    @Test("increment 后计数递增")
    func incrementCountsUp() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let counter = DailyCounter(
            store: makeStore(),
            keyPrefix: "test",
            dayProvider: { clock.now }
        )

        counter.increment()
        counter.increment()

        #expect(counter.todayCount == 2)
    }

    @Test("跨天后计数归零")
    func resetsOnNewDay() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let counter = DailyCounter(store: makeStore(), keyPrefix: "test", dayProvider: { clock.now })
        counter.increment()
        counter.increment()
        #expect(counter.todayCount == 2)

        // 推进到第二天
        clock.advance(by: 60 * 60 * 24)

        #expect(counter.todayCount == 0, "跨天后应归零")
    }

    @Test("跨天后的第一次 increment 从 1 开始")
    func incrementStartsAtOneAfterRollover() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let counter = DailyCounter(store: makeStore(), keyPrefix: "test", dayProvider: { clock.now })
        counter.increment()
        counter.increment()

        clock.advance(by: 60 * 60 * 24)
        counter.increment()

        #expect(counter.todayCount == 1)
    }

    @Test("同一天内的多次读取结果一致")
    func readsAreStableWithinDay() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let counter = DailyCounter(
            store: makeStore(),
            keyPrefix: "test",
            dayProvider: { clock.now }
        )
        counter.increment()

        #expect(counter.todayCount == counter.todayCount)
        #expect(counter.todayCount == 1)
    }

    @Test("不同前缀的计数互不影响")
    func separatePrefixesAreIndependent() {
        let store = makeStore()
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))

        let eyeCare = DailyCounter(store: store, keyPrefix: "eyeCare", dayProvider: { clock.now })
        let hydration = DailyCounter(store: store, keyPrefix: "hydration", dayProvider: { clock.now })

        eyeCare.increment()
        eyeCare.increment()
        hydration.increment()

        #expect(eyeCare.todayCount == 2)
        #expect(hydration.todayCount == 1)
    }

    @Test("reset 把计数清零但仍归属今天")
    func resetClearsCount() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let counter = DailyCounter(
            store: makeStore(),
            keyPrefix: "test",
            dayProvider: { clock.now }
        )
        counter.increment()
        counter.reset()

        #expect(counter.todayCount == 0)
    }

    @Test("计数写入插件状态存储，可被新实例读回")
    func persistsAcrossInstances() {
        let store = makeStore()
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))

        let first = DailyCounter(store: store, keyPrefix: "test", dayProvider: { clock.now })
        first.increment()
        first.increment()

        // 模拟重启：新建计数器实例，共享同一个存储
        let reloaded = DailyCounter(store: store, keyPrefix: "test", dayProvider: { clock.now })

        #expect(reloaded.todayCount == 2, "重启后计数应保留")
    }
}
