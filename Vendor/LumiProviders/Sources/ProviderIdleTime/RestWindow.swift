import Foundation

/// 休息窗口来源。
public enum RestWindowSource: String, Codable, Sendable {
    case weekday
    case weekend
    case globalFallback
    case defaultFallback
}

/// 推断出的「休息窗口」：一天中的一段低活跃时间段。
///
/// 由旧版 `KernelLumi/Types/Idle/RestWindow.swift` 迁移而来。
public struct RestWindow: Codable, Sendable, Equatable {
    public let startMinuteOfDay: Int
    public let endMinuteOfDay: Int
    public let confidence: Double
    public let source: RestWindowSource
    public let generatedAt: Date

    public init(startMinuteOfDay: Int, endMinuteOfDay: Int, confidence: Double,
                source: RestWindowSource, generatedAt: Date) {
        self.startMinuteOfDay = startMinuteOfDay
        self.endMinuteOfDay = endMinuteOfDay
        self.confidence = confidence
        self.source = source
        self.generatedAt = generatedAt
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if startMinuteOfDay <= endMinuteOfDay {
            return minuteOfDay >= startMinuteOfDay && minuteOfDay < endMinuteOfDay
        }
        return minuteOfDay >= startMinuteOfDay || minuteOfDay < endMinuteOfDay
    }

    /// 返回整个区间是否被包含在休息窗口内。
    ///
    /// 窗口结束时刻是排他的；对区间结束减去极小 epsilon，
    /// 使恰好结束在窗口边界的区间有效，同时拒绝跨越边界的区间。
    public func covers(
        startingAt start: Date,
        duration: TimeInterval,
        calendar: Calendar = .current
    ) -> Bool {
        guard duration >= 0 else { return false }
        guard contains(start, calendar: calendar) else { return false }
        guard duration > 0 else { return true }
        return contains(start.addingTimeInterval(duration - 0.001), calendar: calendar)
    }
}

/// 置信度标签：供 UI 展示休息窗口推断的成熟度。
public enum IdleConfidenceLabel: Sendable, Equatable {
    case learning
    case medium
    case high

    public static func label(for confidence: Double, source: RestWindowSource) -> IdleConfidenceLabel {
        if source == .defaultFallback || confidence < 0.45 { return .learning }
        if confidence >= 0.70 { return .high }
        return .medium
    }
}
