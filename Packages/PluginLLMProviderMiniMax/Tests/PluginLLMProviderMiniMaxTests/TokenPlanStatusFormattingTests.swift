import Foundation
import Testing
@testable import PluginLLMProviderMiniMax

/// 工具栏 chip 文案与时长格式化的行为。
@Suite("TokenPlan 展示格式化")
struct TokenPlanStatusFormattingTests {

    // MARK: - chip 文案

    @Test("普通模型按时段%与周%拼接")
    func generalModelJoinsBothPercents() {
        let plans = [
            Self.makePlan(modelName: "general", remainingPercent: 81, weeklyRemainingPercent: 98),
        ]

        #expect(TokenPlanData.statusBarText(from: plans) == "81% · 98%")
    }

    @Test("视频模型拼接当天剩余次数")
    func videoModelAppendsRemainingCount() {
        let plans = [
            Self.makePlan(modelName: "video", intervalTotal: 20, intervalUsage: 18),
        ]

        #expect(TokenPlanData.statusBarText(from: plans) == "2")
    }

    @Test("普通与视频模型同时存在时按顺序拼接")
    func combinesGeneralThenVideo() {
        let plans = [
            Self.makePlan(modelName: "video", intervalTotal: 20, intervalUsage: 18),
            Self.makePlan(modelName: "general", remainingPercent: 81, weeklyRemainingPercent: 98),
        ]

        // 无论输入顺序，普通模型固定在前，保证 chip 文案稳定。
        #expect(TokenPlanData.statusBarText(from: plans) == "81% · 98% · 2")
    }

    @Test("视频模型次数已超用时不为负")
    func videoRemainingCountNeverNegative() {
        let plans = [
            Self.makePlan(modelName: "video", intervalTotal: 20, intervalUsage: 25),
        ]

        #expect(TokenPlanData.statusBarText(from: plans) == "0")
    }

    @Test("非 general/video 模型不出现在 chip 上")
    func unknownModelProducesNoChipText() {
        let plans = [Self.makePlan(modelName: "speech", remainingPercent: 50, weeklyRemainingPercent: 50)]

        #expect(TokenPlanData.statusBarText(from: plans) == nil)
    }

    @Test("空计划不产生 chip 文案")
    func emptyPlansProduceNoChipText() {
        #expect(TokenPlanData.statusBarText(from: []) == nil)
    }

    @Test("model_name 大小写不影响分类")
    func classificationIsCaseInsensitive() {
        let plans = [
            Self.makePlan(modelName: "General", remainingPercent: 40, weeklyRemainingPercent: 60),
            Self.makePlan(modelName: "VIDEO", intervalTotal: 5, intervalUsage: 1),
        ]

        #expect(TokenPlanData.statusBarText(from: plans) == "40% · 60% · 4")
    }

    // MARK: - 相对时长

    @Test("剩余时长按天时拆分")
    func durationSplitsDaysAndHours() throws {
        let duration = try #require(DurationComponents(remainingSeconds: 90_000))

        #expect(duration.days == 1)
        #expect(duration.hours == 1)
        #expect(duration.minutes == 0)
        #expect(duration.seconds == 0)
    }

    @Test("剩余时长按时分拆分")
    func durationSplitsHoursAndMinutes() throws {
        let duration = try #require(DurationComponents(remainingSeconds: 5_400))

        #expect(duration.days == 0)
        #expect(duration.hours == 1)
        #expect(duration.minutes == 30)
    }

    @Test("不足一分钟按秒展示")
    func durationFallsBackToSeconds() throws {
        let duration = try #require(DurationComponents(remainingSeconds: 45))

        #expect(duration.seconds == 45)
        #expect(duration.nonZeroUnits.map(\.unit) == [.second])
    }

    @Test("剩余时间非正时无时长分量")
    func nonPositiveRemainingHasNoDuration() {
        #expect(DurationComponents(remainingSeconds: 0) == nil)
        #expect(DurationComponents(remainingSeconds: -5) == nil)
    }

    @Test("重置时间分量含绝对与相对两段")
    func resetTimeHasAbsoluteAndRelative() throws {
        let components = try #require(
            TokenPlanData.resetTimeComponents(endTime: 1_788_018_000_000, remainsSeconds: 3_600)
        )

        #expect(components.absolute == TokenPlanData.formatTimestamp(1_788_018_000_000))
        #expect(!components.relative.isEmpty)
    }

    @Test("重置时间缺失时无分量")
    func resetTimeMissingHasNoComponents() {
        #expect(TokenPlanData.resetTimeComponents(endTime: 0, remainsSeconds: 0) == nil)
    }

    // MARK: - 状态码与展示配置

    @Test("未知状态码回落为不可用文案 key")
    func unknownStatusFallsBackToQuotaUnavailable() {
        let plan = Self.makePlan(modelName: "general", intervalStatus: 99, weeklyStatus: 99)

        #expect(plan.intervalStatusKey == "Quota unavailable")
        #expect(plan.weeklyStatusKey == "Quota unavailable")
    }

    @Test("已知状态码映射到正常/耗尽 key")
    func knownStatusMapsToLabelKeys() {
        #expect(QuotaStatusCode.normal.rawValue == 1)
        #expect(QuotaStatusCode.normal.labelKey == "Normal")
        #expect(QuotaStatusCode.exhausted.labelKey == "Exhausted")
    }

    @Test("model_name 映射到展示配置")
    func modelDisplayConfigMapping() {
        #expect(TokenPlanModelDisplayConfig.from("general") == .general)
        #expect(TokenPlanModelDisplayConfig.from("video") == .video)
        #expect(TokenPlanModelDisplayConfig.from("speech") == .unknown)
    }

    @Test("时间戳非法时显示占位符")
    func invalidTimestampShowsPlaceholder() {
        #expect(TokenPlanData.formatTimestamp(0) == "—")
        #expect(TokenPlanData.formatTimestamp(-1) == "—")
    }

    // MARK: - 卡片文案

    @Test("调用次数文案含已用与上限")
    func usageTextShowsUsedAndTotal() {
        let text = TokenPlanStatusLocalization.usageText(used: 19, total: 100)

        #expect(text.contains("19"))
        #expect(text.contains("100"))
    }

    @Test("无次数上限时说明不限次")
    func usageTextFallsBackToUnlimited() {
        let text = TokenPlanStatusLocalization.usageText(used: 0, total: 0)

        #expect(!text.isEmpty)
        #expect(!text.contains("0 / 0"))
    }

    @Test("重置倒计时文案只含相对时长")
    func resetCountdownTextOmitsAbsoluteTime() {
        let components = ResetTimeComponents(absolute: "08/01 12:00", relative: "2 小时 32 分")

        let text = TokenPlanStatusLocalization.resetCountdownText(components)

        #expect(text.contains("2 小时 32 分"))
        #expect(!text.contains("08/01 12:00"))
    }

    @Test("剩余次数不为负")
    func remainingCountNeverNegative() {
        let plan = Self.makePlan(modelName: "video", intervalTotal: 20, intervalUsage: 25)

        #expect(plan.intervalRemainingCount == 0)
    }

    // MARK: - Helpers

    private static func makePlan(
        modelName: String,
        remainingPercent: Int = 0,
        weeklyRemainingPercent: Int = 0,
        intervalStatus: Int = 1,
        weeklyStatus: Int = 1,
        intervalTotal: Int = 0,
        intervalUsage: Int = 0
    ) -> TokenPlanData {
        TokenPlanData(
            modelName: modelName,
            remainingPercent: remainingPercent,
            intervalStatus: intervalStatus,
            intervalTotal: intervalTotal,
            intervalUsage: intervalUsage,
            startTime: 0,
            endTime: 0,
            remainsTime: 0,
            weeklyRemainingPercent: weeklyRemainingPercent,
            weeklyStatus: weeklyStatus,
            weeklyTotal: 0,
            weeklyUsage: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0,
            weeklyRemainsTime: 0
        )
    }
}
