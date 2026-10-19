import Foundation
import Testing
@testable import PluginLLMProviderMiniMax

/// 详情面板用到的时间范围与重置时间文案。
///
/// 这些文案此前只由 `TokenPlanDetailView` 使用，因此完全没有单元测试；
/// 但它们都是纯函数输出、用户直接可见，值得独立断言。
@Suite("配额时间文案")
struct TokenPlanTimeFormattingTests {

    // MARK: - 时间范围

    @Test("时段起止时间以破折号连接")
    func intervalTimeRangeJoinsBothEnds() {
        let plan = makePlan(startTime: 1_788_000_000_000, endTime: 1_788_018_000_000)

        let expectedStart = TokenPlanData.formatTimestamp(1_788_000_000_000)
        let expectedEnd = TokenPlanData.formatTimestamp(1_788_018_000_000)
        #expect(plan.intervalTimeRange == "\(expectedStart) — \(expectedEnd)")
    }

    @Test("本周起止时间以破折号连接")
    func weeklyTimeRangeJoinsBothEnds() {
        let plan = makePlan(weeklyStartTime: 1_787_500_000_000, weeklyEndTime: 1_788_100_000_000)

        let expectedStart = TokenPlanData.formatTimestamp(1_787_500_000_000)
        let expectedEnd = TokenPlanData.formatTimestamp(1_788_100_000_000)
        #expect(plan.weeklyTimeRange == "\(expectedStart) — \(expectedEnd)")
    }

    @Test("时间戳缺失时范围显示占位符")
    func missingTimestampsShowPlaceholder() {
        let plan = makePlan()

        #expect(plan.intervalTimeRange == "— — —")
        #expect(plan.weeklyTimeRange == "— — —")
    }

    // MARK: - 重置时间分量

    @Test("时段重置时间分量含绝对与相对两段")
    func intervalRemainsComponents() throws {
        let plan = makePlan(endTime: 1_788_018_000_000, remainsTime: 5_400)

        let components = try #require(plan.remainsTimeComponents)
        #expect(components.absolute == TokenPlanData.formatTimestamp(1_788_018_000_000))
        #expect(!components.relative.isEmpty)
    }

    @Test("本周重置时间分量含绝对与相对两段")
    func weeklyRemainsComponents() throws {
        let plan = makePlan(weeklyEndTime: 1_788_100_000_000, weeklyRemainsTime: 345_600)

        let components = try #require(plan.weeklyRemainsTimeComponents)
        #expect(components.absolute == TokenPlanData.formatTimestamp(1_788_100_000_000))
        #expect(!components.relative.isEmpty)
    }

    @Test("剩余时间为 0 时没有重置分量")
    func zeroRemainingHasNoComponents() {
        let plan = makePlan(endTime: 1_788_018_000_000, remainsTime: 0)

        #expect(plan.remainsTimeComponents == nil)
        #expect(plan.weeklyRemainsTimeComponents == nil)
    }

    // MARK: - 重置时间文本

    @Test("重置时间文本含绝对时间与相对时长")
    func resetTimeTextContainsBothParts() {
        let components = ResetTimeComponents(absolute: "08/01 12:00", relative: "1 小时")

        let text = TokenPlanStatusLocalization.resetTimeText(components)

        #expect(text.contains("08/01 12:00"))
        #expect(text.contains("1 小时"))
    }

    // MARK: - 相对时长拼接

    @Test("天与小时拼接")
    func durationJoinsDaysAndHours() {
        let duration = DurationComponents(days: 1, hours: 3)

        #expect(!TokenPlanStatusLocalization.durationText(duration).isEmpty)
    }

    @Test("分钟与秒拼接")
    func durationJoinsMinutesAndSeconds() throws {
        // 90 秒 → 1 分钟 + 30 秒，覆盖「不足一小时」的 minutes+seconds 分支。
        let duration = try #require(DurationComponents(remainingSeconds: 90))

        #expect(duration.minutes == 1)
        #expect(duration.seconds == 30)
        #expect(duration.nonZeroUnits.map(\.unit) == [.minute, .second])
        #expect(!TokenPlanStatusLocalization.durationText(duration).isEmpty)
    }

    @Test("空时长的拼接结果为空串")
    func emptyDurationProducesEmptyText() {
        #expect(DurationComponents().nonZeroUnits.isEmpty)
        #expect(TokenPlanStatusLocalization.durationText(DurationComponents()).isEmpty)
    }

    @Test("非零单位按从大到小排列")
    func unitsAreOrderedDescending() throws {
        let duration = try #require(DurationComponents(remainingSeconds: 90_061))

        #expect(duration.nonZeroUnits.map(\.unit) == [.day, .hour])
    }

    // MARK: - Helpers

    private func makePlan(
        startTime: Int64 = 0,
        endTime: Int64 = 0,
        remainsTime: Int64 = 0,
        weeklyStartTime: Int64 = 0,
        weeklyEndTime: Int64 = 0,
        weeklyRemainsTime: Int64 = 0
    ) -> TokenPlanData {
        TokenPlanData(
            modelName: "general",
            remainingPercent: 50,
            intervalStatus: 1,
            intervalTotal: 10,
            intervalUsage: 5,
            startTime: startTime,
            endTime: endTime,
            remainsTime: remainsTime,
            weeklyRemainingPercent: 50,
            weeklyStatus: 1,
            weeklyTotal: 10,
            weeklyUsage: 5,
            weeklyStartTime: weeklyStartTime,
            weeklyEndTime: weeklyEndTime,
            weeklyRemainsTime: weeklyRemainsTime
        )
    }
}
