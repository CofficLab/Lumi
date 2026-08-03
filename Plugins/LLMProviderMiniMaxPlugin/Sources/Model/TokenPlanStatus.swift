import Foundation

/// MiniMax Token Plan 配额状态
enum TokenPlanStatus: Sendable {
    case loading
    case success([TokenPlanData])
    case authError
    case unavailable
}

/// 时段/周配额状态码语义
enum QuotaStatusCode: Int, Sendable {
    /// 正常可用
    case normal = 1
    /// 已耗尽 / 不可用
    case exhausted = 2

    var label: String {
        switch self {
        case .normal: return "正常"
        case .exhausted: return "已耗尽"
        }
    }
}

/// MiniMax Token Plan API 响应数据
///
/// 新版接口 `/v1/token_plan/remains` 返回 `model_remains` 数组（顶层），
/// 字段为 `model_name` 与各类 `remaining_percent` / 计数 / 时间戳。
struct TokenPlanData: Sendable {
    let modelName: String

    // MARK: - 当前时段 (interval)

    /// 当前时段剩余百分比（0-100）
    let remainingPercent: Int
    /// 当前时段状态码（1=正常, 2=已耗尽）
    let intervalStatus: Int
    /// 当前时段总调用次数
    let intervalTotal: Int
    /// 当前时段已用调用次数
    let intervalUsage: Int
    /// 当前时段开始时间（毫秒时间戳）
    let startTime: Int64
    /// 当前时段结束时间（毫秒时间戳）
    let endTime: Int64
    /// 当前时段剩余秒数
    let remainsTime: Int64

    // MARK: - 本周 (weekly)

    /// 本周剩余百分比（0-100）
    let weeklyRemainingPercent: Int
    /// 本周状态码（1=正常, 2=已耗尽）
    let weeklyStatus: Int
    /// 本周总调用次数
    let weeklyTotal: Int
    /// 本周已用调用次数
    let weeklyUsage: Int
    /// 本周开始时间（毫秒时间戳）
    let weeklyStartTime: Int64
    /// 本周结束时间（毫秒时间戳）
    let weeklyEndTime: Int64
    /// 本周剩余秒数
    let weeklyRemainsTime: Int64

    // MARK: - 状态栏显示

    /// 是否为视频模型
    var isVideoModel: Bool {
        modelName.lowercased().contains("video")
    }

    /// 是否为普通模型
    var isGeneralModel: Bool {
        modelName.lowercased().contains("general")
    }

    /// 格式化剩余时间文本（状态栏用）
    ///
    /// 格式: "X小时剩余" 或 "X分钟剩余"
    var formattedRemainsTime: String {
        Self.formatDurationCompact(remainsTime)
    }

    /// 状态栏显示文本
    ///
    /// 格式: "81% · 98% · 2"（普通模型时段剩余% · 普通模型周额度剩余% · 视频模型当天剩余次数）
    static func statusBarText(from plans: [TokenPlanData]) -> String {
        // 按模型类型分组
        let generalPlans = plans.filter { $0.isGeneralModel }
        let videoPlans = plans.filter { $0.isVideoModel }

        var parts: [String] = []

        // 普通模型：时段剩余百分比 + 周额度剩余百分比
        if let general = generalPlans.first {
            parts.append("\(general.remainingPercent)%")
            parts.append("\(general.weeklyRemainingPercent)%")
        }

        // 视频模型：当天剩余次数
        if let video = videoPlans.first {
            let remainingCount = max(0, video.intervalTotal - video.intervalUsage)
            parts.append("\(remainingCount)")
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Derived

    /// 格式化状态栏显示文本
    /// 格式: "40% · 50%" (时段剩余% · 周剩余%)
    var statusText: String {
        return "\(remainingPercent)% · \(weeklyRemainingPercent)%"
    }

    /// 剩余百分比
    var remainingPercentage: Double {
        return Double(remainingPercent)
    }

    /// 当前时段状态语义
    var intervalStatusLabel: String {
        QuotaStatusCode(rawValue: intervalStatus)?.label ?? "未知(\(intervalStatus))"
    }

    /// 本周状态语义
    var weeklyStatusLabel: String {
        QuotaStatusCode(rawValue: weeklyStatus)?.label ?? "未知(\(weeklyStatus))"
    }

    /// 当前时段起止时间文本
    var intervalTimeRange: String {
        "\(Self.formatTimestamp(startTime)) — \(Self.formatTimestamp(endTime))"
    }

    /// 本周起止时间文本
    var weeklyTimeRange: String {
        "\(Self.formatTimestamp(weeklyStartTime)) — \(Self.formatTimestamp(weeklyEndTime))"
    }

    /// 当前时段重置时间文本
    ///
    /// 格式: "MM/dd HH:mm（相对时间）"，例如 "08/01 12:00（1小时后）"
    var remainsTimeText: String {
        Self.formatResetTime(endTime: endTime, remainsSeconds: remainsTime)
    }

    /// 本周重置时间文本
    ///
    /// 格式: "MM/dd HH:mm（相对时间）"，例如 "08/07 00:00（5天后）"
    var weeklyRemainsTimeText: String {
        Self.formatResetTime(endTime: weeklyEndTime, remainsSeconds: weeklyRemainsTime)
    }

    // MARK: - Formatters

    /// 毫秒时间戳 → "MM/dd HH:mm"
    private static func formatTimestamp(_ ms: Int64) -> String {
        guard ms > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: Double(ms) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    /// 秒数 → "Xd Xh" / "Xh Xm" / "Xm Xs" / "Xs"
    private static func formatDuration(_ seconds: Int64) -> String {
        guard seconds > 0 else { return "—" }
        let s = seconds
        let days = s / 86400
        let hours = (s % 86400) / 3600
        let minutes = (s % 3600) / 60
        let secs = s % 60

        if days > 0 {
            return "\(days)天\(hours)小时"
        } else if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟\(secs)秒"
        } else {
            return "\(secs)秒"
        }
    }

    /// 秒数 → "X小时" / "X分钟" / "X秒"（紧凑格式，用于状态栏）
    private static func formatDurationCompact(_ seconds: Int64) -> String {
        guard seconds > 0 else { return "—" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)小时剩余"
        } else if minutes > 0 {
            return "\(minutes)分钟剩余"
        } else {
            return "\(seconds)秒剩余"
        }
    }

    /// 重置时间文本
    ///
    /// 格式: "MM/dd HH:mm（相对时间）"，例如 "08/01 12:00（1小时后）"
    /// - Parameters:
    ///   - endTime: 重置时间戳（毫秒）
    ///   - remainsSeconds: 剩余秒数
    private static func formatResetTime(endTime: Int64, remainsSeconds: Int64) -> String {
        guard remainsSeconds > 0 else { return "—" }
        let resetDate = Date(timeIntervalSince1970: Double(endTime) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.timeZone = .current
        let absoluteTime = formatter.string(from: resetDate)
        let relativeTime = Self.formatDuration(remainsSeconds)
        return "\(absoluteTime)（\(relativeTime)）"
    }
}
