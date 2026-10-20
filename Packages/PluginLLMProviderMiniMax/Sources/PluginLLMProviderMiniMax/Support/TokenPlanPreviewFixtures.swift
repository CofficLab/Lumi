import Foundation

#if DEBUG
/// 预览与单测共用的固定配额样本。
///
/// 集中一处避免各处预览重复粘贴大段构造参数，也保证预览展示的数值与
/// `TokenPlanStatusTests` 断言的一致。
enum TokenPlanPreviewFixtures {

    /// 常规模型：时段 81%、本周 98%。
    static let generalPlan = TokenPlanData(
        modelName: "general",
        remainingPercent: 81,
        intervalStatus: QuotaStatusCode.normal.rawValue,
        intervalTotal: 100,
        intervalUsage: 19,
        startTime: 1_788_000_000_000,
        endTime: 1_788_018_000_000,
        remainsTime: 12_345,
        weeklyRemainingPercent: 98,
        weeklyStatus: QuotaStatusCode.normal.rawValue,
        weeklyTotal: 500,
        weeklyUsage: 10,
        weeklyStartTime: 1_787_500_000_000,
        weeklyEndTime: 1_788_100_000_000,
        weeklyRemainsTime: 345_600
    )

    /// 视频模型：时段次数耗尽、周额度偏低，用于详情面板的多模型分段。
    static let videoPlan = TokenPlanData(
        modelName: "video",
        remainingPercent: 0,
        intervalStatus: QuotaStatusCode.exhausted.rawValue,
        intervalTotal: 20,
        intervalUsage: 20,
        startTime: 1_788_000_000_000,
        endTime: 1_788_018_000_000,
        remainsTime: 12_345,
        weeklyRemainingPercent: 40,
        weeklyStatus: QuotaStatusCode.normal.rawValue,
        weeklyTotal: 100,
        weeklyUsage: 60,
        weeklyStartTime: 1_787_500_000_000,
        weeklyEndTime: 1_788_100_000_000,
        weeklyRemainsTime: 345_600
    )

    static let allPlans = [generalPlan, videoPlan]
}
#endif
