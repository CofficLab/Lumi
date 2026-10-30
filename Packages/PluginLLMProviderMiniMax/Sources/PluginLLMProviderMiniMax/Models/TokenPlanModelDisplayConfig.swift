import Foundation

/// 配额周期的展示口径。
///
/// MiniMax 对不同模型给出的额度粒度不同：常规模型给出时段 / 周的**剩余百分比**，
/// 视频模型的时段额度只给**调用次数**（百分比恒为 0）。两种口径需要不同的主数值
/// 样式与进度条表现，因此在展示配置里显式区分。
enum TokenPlanMetric: Sendable {
    /// 按剩余百分比展示，主数值带进度条。
    case percent
    /// 按剩余调用次数展示，主数值不带进度条。
    case count
}

/// 模型展示配置：把接口返回的 `model_name` 映射为详情面板的展示文案。
///
/// 均为本地化 key，实际字符串由 ``TokenPlanStatusLocalization`` 所在层的
/// `pluginLocalization` 解析，避免模型层持有语言相关字面量。
enum TokenPlanModelDisplayConfig {

    case general
    case video
    case unknown

    var displayNameKey: String {
        switch self {
        case .general: return "General Model"
        case .video: return "Video Model"
        case .unknown: return "Unknown Model"
        }
    }

    var intervalTitleKey: String {
        switch self {
        case .general, .video: return "5-Hour Window"
        case .unknown: return "Current Interval"
        }
    }

    var intervalDescriptionKey: String {
        switch self {
        case .general: return "General model 5-hour call limit"
        case .video: return "Video model 5-hour call limit"
        case .unknown: return "Unknown Model"
        }
    }

    /// 时段（5 小时窗口）的展示口径。
    var intervalMetric: TokenPlanMetric {
        switch self {
        case .general, .unknown: return .percent
        case .video: return .count
        }
    }

    /// 本周配额的展示口径。
    var weeklyMetric: TokenPlanMetric {
        switch self {
        case .general, .video, .unknown: return .percent
        }
    }

    /// 模型分组的图标名。
    var iconName: String {
        switch self {
        case .general: return "cpu"
        case .video: return "film"
        case .unknown: return "square.dashed"
        }
    }

    static func from(_ modelName: String) -> TokenPlanModelDisplayConfig {
        switch modelName.lowercased() {
        case "general": return .general
        case "video": return .video
        default: return .unknown
        }
    }
}

// MARK: - Remaining Ratio

extension TokenPlanModelDisplayConfig {

    /// 该模型各周期的剩余比例（0-1），用于「紧急度」着色。
    ///
    /// 比例口径与展示口径一致：百分比周期直接取百分比，次数周期用「剩余次数 /
    /// 上限次数」；无上限（次数为 0）时该项不参与紧急度判断。
    func remainingRatios(for plan: TokenPlanData) -> [Double] {
        var ratios: [Double] = []

        if let ratio = Self.ratio(
            metric: intervalMetric,
            percent: plan.remainingPercent,
            usage: plan.intervalUsage,
            total: plan.intervalTotal
        ) {
            ratios.append(ratio)
        }

        if let ratio = Self.ratio(
            metric: weeklyMetric,
            percent: plan.weeklyRemainingPercent,
            usage: plan.weeklyUsage,
            total: plan.weeklyTotal
        ) {
            ratios.append(ratio)
        }

        return ratios
    }

    private static func ratio(
        metric: TokenPlanMetric,
        percent: Int,
        usage: Int,
        total: Int
    ) -> Double? {
        switch metric {
        case .percent:
            return Double(percent) / 100
        case .count:
            guard total > 0 else { return nil }
            return Double(max(0, total - usage)) / Double(total)
        }
    }
}
