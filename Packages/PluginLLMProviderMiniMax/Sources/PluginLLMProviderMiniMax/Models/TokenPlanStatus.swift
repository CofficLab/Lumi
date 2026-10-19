import Foundation

/// MiniMax Token Plan 配额状态。
enum TokenPlanStatus: Sendable, Equatable {
    case loading
    case success([TokenPlanData])
    case authError
    case unavailable
}

/// 时段 / 周配额状态码语义（1=正常，2=已耗尽）。
enum QuotaStatusCode: Int, Sendable {
    case normal = 1
    case exhausted = 2

    /// 本地化 key，见 `Resources/Localizable.xcstrings`。
    var labelKey: String {
        switch self {
        case .normal: return "Normal"
        case .exhausted: return "Exhausted"
        }
    }
}

/// 相对时长的单位。
enum DurationUnit: String, Sendable, CaseIterable {
    case day
    case hour
    case minute
    case second

    /// 带 `%lld` 占位符的本地化 key。
    var templateKey: String {
        "Duration.\(rawValue)s"
    }
}

/// 相对时长的展示分量。
struct DurationComponents: Sendable, Equatable {
    let days: Int64
    let hours: Int64
    let minutes: Int64
    let seconds: Int64

    init(days: Int64 = 0, hours: Int64 = 0, minutes: Int64 = 0, seconds: Int64 = 0) {
        self.days = days
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }

    /// 从剩余秒数拆分：只保留最大两个单位（天/时 → 时/分 → 分/秒 → 秒）。
    /// 返回 `nil` 表示剩余时间已耗尽或数据缺失。
    init?(remainingSeconds: Int64) {
        guard remainingSeconds > 0 else { return nil }
        let days = remainingSeconds / 86_400
        let hours = (remainingSeconds % 86_400) / 3_600
        let minutes = (remainingSeconds % 3_600) / 60
        let secs = remainingSeconds % 60

        if days > 0 {
            self.init(days: days, hours: hours)
        } else if hours > 0 {
            self.init(hours: hours, minutes: minutes)
        } else if minutes > 0 {
            self.init(minutes: minutes, seconds: secs)
        } else {
            self.init(seconds: secs)
        }
    }

    /// 单位 → 数量，仅含非零项。
    var nonZeroUnits: [(unit: DurationUnit, value: Int64)] {
        DurationUnit.allCases.compactMap { unit in
            let value: Int64
            switch unit {
            case .day: value = days
            case .hour: value = hours
            case .minute: value = minutes
            case .second: value = seconds
            }
            guard value > 0 else { return nil }
            return (unit, value)
        }
    }

    var isEmpty: Bool { nonZeroUnits.isEmpty }
}

/// 重置时间的展示分量。
struct ResetTimeComponents: Sendable, Equatable {
    /// 绝对时间，`MM/dd HH:mm`。
    let absolute: String
    /// 相对剩余时长，如 `1小时30分钟`。
    let relative: String
}

/// MiniMax Token Plan API 响应数据。
///
/// 接口 `/v1/token_plan/remains` 返回 `model_remains` 数组（顶层），字段为
/// `model_name` 与各类 `remaining_percent` / 计数 / 时间戳。
struct TokenPlanData: Sendable, Equatable {

    // MARK: - Init

    init(
        modelName: String,
        remainingPercent: Int,
        intervalStatus: Int,
        intervalTotal: Int,
        intervalUsage: Int,
        startTime: Int64,
        endTime: Int64,
        remainsTime: Int64,
        weeklyRemainingPercent: Int,
        weeklyStatus: Int,
        weeklyTotal: Int,
        weeklyUsage: Int,
        weeklyStartTime: Int64,
        weeklyEndTime: Int64,
        weeklyRemainsTime: Int64
    ) {
        self.modelName = modelName
        self.remainingPercent = remainingPercent
        self.intervalStatus = intervalStatus
        self.intervalTotal = intervalTotal
        self.intervalUsage = intervalUsage
        self.startTime = startTime
        self.endTime = endTime
        self.remainsTime = remainsTime
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.weeklyStatus = weeklyStatus
        self.weeklyTotal = weeklyTotal
        self.weeklyUsage = weeklyUsage
        self.weeklyStartTime = weeklyStartTime
        self.weeklyEndTime = weeklyEndTime
        self.weeklyRemainsTime = weeklyRemainsTime
    }

    let modelName: String

    // MARK: - 当前时段（interval）

    /// 当前时段剩余百分比（0-100）。
    let remainingPercent: Int
    /// 当前时段状态码（1=正常，2=已耗尽）。
    let intervalStatus: Int
    /// 当前时段总调用次数。
    let intervalTotal: Int
    /// 当前时段已用调用次数。
    let intervalUsage: Int
    /// 当前时段开始时间（毫秒时间戳）。
    let startTime: Int64
    /// 当前时段结束时间（毫秒时间戳）。
    let endTime: Int64
    /// 当前时段剩余秒数。
    let remainsTime: Int64

    // MARK: - 本周（weekly）

    /// 本周剩余百分比（0-100）。
    let weeklyRemainingPercent: Int
    /// 本周状态码（1=正常，2=已耗尽）。
    let weeklyStatus: Int
    /// 本周总调用次数。
    let weeklyTotal: Int
    /// 本周已用调用次数。
    let weeklyUsage: Int
    /// 本周开始时间（毫秒时间戳）。
    let weeklyStartTime: Int64
    /// 本周结束时间（毫秒时间戳）。
    let weeklyEndTime: Int64
    /// 本周剩余秒数。
    let weeklyRemainsTime: Int64

    // MARK: - 分类

    /// 是否为视频模型。
    var isVideoModel: Bool {
        modelName.lowercased().contains("video")
    }

    /// 是否为普通模型。
    var isGeneralModel: Bool {
        modelName.lowercased().contains("general")
    }

    // MARK: - 工具栏显示

    /// 工具栏 chip 文本。
    ///
    /// 按可用项拼接 `普通模型时段剩余% · 普通模型周剩余% · 视频模型当天剩余次数`
    /// （如 `81% · 98% · 2`）；无可用项时返回 `nil`，由调用方隐藏 chip。
    static func statusBarText(from plans: [TokenPlanData]) -> String? {
        var parts: [String] = []

        if let general = plans.first(where: \.isGeneralModel) {
            parts.append("\(general.remainingPercent)%")
            parts.append("\(general.weeklyRemainingPercent)%")
        }

        if let video = plans.first(where: \.isVideoModel) {
            parts.append("\(max(0, video.intervalTotal - video.intervalUsage))")
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    // MARK: - Derived

    /// 当前时段状态本地化 key。
    var intervalStatusKey: String {
        QuotaStatusCode(rawValue: intervalStatus)?.labelKey ?? "Quota unavailable"
    }

    /// 本周状态本地化 key。
    var weeklyStatusKey: String {
        QuotaStatusCode(rawValue: weeklyStatus)?.labelKey ?? "Quota unavailable"
    }

    /// 当前时段起止时间文本（`MM/dd HH:mm — MM/dd HH:mm`）。
    var intervalTimeRange: String {
        "\(Self.formatTimestamp(startTime)) — \(Self.formatTimestamp(endTime))"
    }

    /// 本周起止时间文本。
    var weeklyTimeRange: String {
        "\(Self.formatTimestamp(weeklyStartTime)) — \(Self.formatTimestamp(weeklyEndTime))"
    }

    /// 时段起止时间文本（紧凑版）。
    ///
    /// 同一天内时省略结束日期（`10/19 17:26 → 22:26`），跨天时保留完整时间戳。
    var intervalTimeRangeCompact: String {
        Self.formatTimeRange(start: startTime, end: endTime)
    }

    /// 本周起止时间文本（紧凑版）。
    var weeklyTimeRangeCompact: String {
        Self.formatTimeRange(start: weeklyStartTime, end: weeklyEndTime)
    }

    /// 时段剩余调用次数。
    var intervalRemainingCount: Int {
        max(0, intervalTotal - intervalUsage)
    }

    /// 本周剩余调用次数。
    var weeklyRemainingCount: Int {
        max(0, weeklyTotal - weeklyUsage)
    }

    /// 当前时段重置时间展示分量；数据缺失时为 `nil`。
    var remainsTimeComponents: ResetTimeComponents? {
        Self.resetTimeComponents(endTime: endTime, remainsSeconds: remainsTime)
    }

    /// 本周重置时间展示分量；数据缺失时为 `nil`。
    var weeklyRemainsTimeComponents: ResetTimeComponents? {
        Self.resetTimeComponents(endTime: weeklyEndTime, remainsSeconds: weeklyRemainsTime)
    }

    // MARK: - Formatters

    /// 毫秒时间戳 → `MM/dd HH:mm`；无效时间戳返回 `—`。
    ///
    /// 固定 POSIX locale，避免用户日历使用非 Gregorian 历法时输出混杂符号。
    static func formatTimestamp(_ ms: Int64) -> String {
        guard ms > 0 else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.timeZone = .current
        return formatter.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    /// 毫秒时间戳 → `HH:mm`；无效时间戳返回 `—`。
    static func formatClock(_ ms: Int64) -> String {
        guard ms > 0 else { return "—" }
        return Self.format(ms, format: "HH:mm")
    }

    /// 毫秒时间戳 → `MM/dd`；无效时间戳返回 `—`。
    static func formatDatePart(_ ms: Int64) -> String {
        guard ms > 0 else { return "—" }
        return Self.format(ms, format: "MM/dd")
    }

    /// 时间段紧凑文本：同一天时结束侧省略日期。
    ///
    /// 详情面板的卡片宽度有限，完整时间段会被截断；这里在同一天时压成
    /// `MM/dd HH:mm → HH:mm`，跨天时保留完整日期。
    static func formatTimeRange(start: Int64, end: Int64) -> String {
        guard start > 0, end > 0 else { return "—" }
        if Self.formatDatePart(start) == Self.formatDatePart(end) {
            return "\(Self.formatTimestamp(start)) → \(Self.formatClock(end))"
        }
        return "\(Self.formatTimestamp(start)) → \(Self.formatTimestamp(end))"
    }

    private static func format(_ ms: Int64, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        formatter.timeZone = .current
        return formatter.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    /// 重置时间展示分量；剩余时间非正时返回 `nil`。
    ///
    /// 文案本身由 `TokenPlanStatusLocalization` 按当前语言生成，模型层只提供数据。
    static func resetTimeComponents(endTime: Int64, remainsSeconds: Int64) -> ResetTimeComponents? {
        guard let duration = DurationComponents(remainingSeconds: remainsSeconds), !duration.isEmpty else {
            return nil
        }
        return ResetTimeComponents(
            absolute: formatTimestamp(endTime),
            relative: TokenPlanStatusLocalization.durationText(duration)
        )
    }
}

/// Token Plan 的文案拼接集中处，模型层只负责给数据。
enum TokenPlanStatusLocalization {

    /// 相对时长文本，单位按「天 → 时 → 分 → 秒」顺序拼接。
    static func durationText(_ duration: DurationComponents) -> String {
        duration.nonZeroUnits
            .map { String(format: pluginLocalization.string($0.unit.templateKey), $0.value) }
            .joined()
    }

    /// 重置时间文本 `绝对时间（相对时长）`。
    ///
    /// 括号形态随语言而变（中文全角、英文半角），故走本地化格式串而非硬编码。
    static func resetTimeText(_ components: ResetTimeComponents) -> String {
        String(
            format: pluginLocalization.string("Reset time format"),
            components.absolute,
            components.relative
        )
    }

    /// 重置倒计时文本 `2 小时 32 分后重置`。
    ///
    /// 卡片里只放倒计时（绝对时间由时间段一行承担），避免同一信息出现两次。
    static func resetCountdownText(_ components: ResetTimeComponents) -> String {
        String(
            format: pluginLocalization.string("Resets in %@"),
            components.relative
        )
    }

    /// 调用次数文本 `已用 19 / 100`；无次数上限时说明不限次。
    static func usageText(used: Int, total: Int) -> String {
        guard total > 0 else { return pluginLocalization.string("Unlimited calls") }
        return String(
            format: pluginLocalization.string("Used %lld / %lld"),
            Int64(used),
            Int64(total)
        )
    }
}
