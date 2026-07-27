import Foundation

/// MiniMax Token Plan 配额状态
enum TokenPlanStatus {
    case loading
    case success(TokenPlanData)
    case authError
    case unavailable
}

/// MiniMax Token Plan API 响应数据
///
/// 新版接口 `/v1/token_plan/remains` 返回 `model_remains` 数组（顶层），
/// 字段为 `model_name` 与各类 `remaining_percent` / 计数，不再提供 token 的 total/remains。
struct TokenPlanData {
    let modelName: String
    /// 当前时段剩余百分比（0-100）
    let remainingPercent: Int
    /// 本周剩余百分比（0-100）
    let weeklyRemainingPercent: Int
    /// 当前时段总调用次数
    let intervalTotal: Int
    /// 当前时段已用调用次数
    let intervalUsage: Int

    /// 格式化状态栏显示文本
    var statusText: String {
        let shortModel = modelName.split(separator: "-").first.map(String.init) ?? modelName
        return String(format: "%d%% %@", remainingPercent, shortModel)
    }

    /// 剩余百分比
    var remainingPercentage: Double {
        return Double(remainingPercent)
    }
}
