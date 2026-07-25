import LumiUI
import SwiftUI

// MARK: - MetricStatus

/// 指标的状态分级。
///
/// 不直接携带颜色——颜色由 `LumiTheme` 解析,这样状态色会跟随当前主题
/// (Lumi / Aurora / Dracula …),而不是写死成 SwiftUI 的 `.green/.orange/.red`。
enum MetricStatus {
    /// 正常(低占用 / 电量充足 / 温度低)
    case normal
    /// 警告(中占用 / 电量偏低 / 温度偏高)
    case warning
    /// 临界(高占用 / 电量耗尽 / 温度过高)
    case critical
}

extension MetricStatus {
    /// 把状态映射为当前主题下的语义色。
    @MainActor
    var themeColor: Color {
        switch self {
        case .normal: return currentTheme.success
        case .warning: return currentTheme.warning
        case .critical: return currentTheme.error
        }
    }

    /// 把状态映射为指定主题下的语义色(供已持有 `@LumiTheme` 的视图使用,避免重复读全局)。
    func color(in theme: any LumiUITheme) -> Color {
        switch self {
        case .normal: return theme.success
        case .warning: return theme.warning
        case .critical: return theme.error
        }
    }
}

// MARK: - Percentage Helpers

/// 按百分比(0–100)划分 CPU/GPU/内存等“越高越糟”的指标状态。
///
/// 阈值与各 ViewModel 原有的 `metricColor` 完全一致(<60 normal,<85 warning,否则 critical),
/// 统一收口到一处,消除散落的重复逻辑。
enum MetricStatusScale {
    /// 适用于 0–100 百分比。
    static func from(percentage value: Double) -> MetricStatus {
        if value < 60 { return .normal }
        if value < 85 { return .warning }
        return .critical
    }

    /// 适用于 0.0–1.0 比例(SystemMonitorViewModel 用的是 0–1)。
    static func from(ratio value: Double) -> MetricStatus {
        from(percentage: value * 100)
    }
}

// MARK: - Battery / Temperature Helpers

extension MetricStatus {
    /// 电池电量(0–1.0)→状态。>50% normal,>20% warning,否则 critical。
    static func batteryLevel(_ level: Double) -> MetricStatus {
        let pct = level * 100
        if pct > 50 { return .normal }
        if pct > 20 { return .warning }
        return .critical
    }

    /// 电池健康度(0–100)→状态。≥80 normal,≥60 warning,否则 critical。
    static func batteryHealth(_ health: Double) -> MetricStatus {
        if health >= 80 { return .normal }
        if health >= 60 { return .warning }
        return .critical
    }

    /// 电池/设备温度(℃)→状态。<35 normal,<45 warning,否则 critical。
    static func temperature(_ temp: Double) -> MetricStatus {
        if temp < 35 { return .normal }
        if temp < 45 { return .warning }
        return .critical
    }

    /// GPU 温度(℃)→状态(GPU 阈值更高)。<60 normal,<80 warning,否则 critical。
    static func gpuTemperature(_ temp: Double) -> MetricStatus {
        if temp < 60 { return .normal }
        if temp < 80 { return .warning }
        return .critical
    }
}
