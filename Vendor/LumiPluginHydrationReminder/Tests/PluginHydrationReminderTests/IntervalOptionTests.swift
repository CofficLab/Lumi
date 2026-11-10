import Foundation
import Testing
@testable import PluginHydrationReminder

/// `IntervalOption` 与 `commonIntervals` 是 Manager 中唯一的纯值逻辑层，
/// 可脱离单例与 UserDefaults 直接验证。
typealias IntervalOption = HydrationReminderManager.IntervalOption

@Suite("IntervalOption 语义")
struct IntervalOptionTests {
    @Test("minutes 换算为秒")
    func minutesToSeconds() {
        #expect(IntervalOption.minutes(10).timeInterval == 600)
        #expect(IntervalOption.minutes(30).timeInterval == 1800)
        #expect(IntervalOption.minutes(45).timeInterval == 2700)
    }

    @Test("hours 换算为秒")
    func hoursToSeconds() {
        #expect(IntervalOption.hours(1).timeInterval == 3600)
        #expect(IntervalOption.hours(2).timeInterval == 7200)
        #expect(IntervalOption.hours(3).timeInterval == 10800)
    }

    @Test("id 以 m / h 前缀区分单位")
    func identifiersUseUnitPrefix() {
        #expect(IntervalOption.minutes(30).id == "m30")
        #expect(IntervalOption.hours(2).id == "h2")
    }

    @Test("id 在同单位同数值下相同，跨单位不同")
    func identifiersAreStable() {
        #expect(IntervalOption.minutes(1).id == IntervalOption.minutes(1).id)
        #expect(IntervalOption.minutes(1).id != IntervalOption.hours(1).id)
    }

    @Test("同数值可存入 Set 去重")
    func deduplicatesInSet() {
        let set: Set<IntervalOption> = [
            .minutes(30),
            .minutes(30),
            .hours(1),
        ]
        #expect(set.count == 2)
    }

    @Test("equality 仅依赖 case 与数值")
    func equalityIsValueBased() {
        #expect(IntervalOption.minutes(10) == .minutes(10))
        #expect(IntervalOption.hours(1) != .hours(2))
    }

    @Test("displayName 可解析且非空")
    func displayNamesAreResolvable() {
        // 走 xcstrings 查表，未命中时回退到 key 本身，同样非空
        #expect(!IntervalOption.minutes(10).displayName.isEmpty)
        #expect(!IntervalOption.hours(1).displayName.isEmpty)
    }

    @Test("作为 Identifiable 可直接用于列表")
    func conformsToIdentifiable() {
        #expect(IntervalOption.hours(3).id == "h3")
    }
}

@Suite("commonIntervals 预设")
@MainActor
struct CommonIntervalsTests {
    @Test("包含 5 个预设间隔")
    func hasFivePresets() {
        #expect(HydrationReminderManager.commonIntervals.count == 5)
    }

    @Test("预设覆盖分钟与小时两种单位")
    func coversBothUnits() {
        let intervals = HydrationReminderManager.commonIntervals
        #expect(intervals.contains(.minutes(10)))
        #expect(intervals.contains(.minutes(30)))
        #expect(intervals.contains(.hours(1)))
        #expect(intervals.contains(.hours(2)))
        #expect(intervals.contains(.hours(3)))
    }

    @Test("预设按时间递增排列")
    func isSortedAscending() {
        let intervals = HydrationReminderManager.commonIntervals
        #expect(intervals.map(\.timeInterval) == intervals.map(\.timeInterval).sorted())
    }

    @Test("预设间隔互不重复")
    func hasNoDuplicates() {
        let intervals = HydrationReminderManager.commonIntervals
        #expect(Set(intervals).count == intervals.count)
    }

    @Test("index 2（默认回退目标）为 1 小时")
    func defaultFallbackIndex() {
        // removeInterval / resetIntervals 在移除当前选中项时回退到 commonIntervals[2]
        #expect(HydrationReminderManager.commonIntervals[2] == .hours(1))
        #expect(HydrationReminderManager.commonIntervals[2].timeInterval == 3600)
    }
}
