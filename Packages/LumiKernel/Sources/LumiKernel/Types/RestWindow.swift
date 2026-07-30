import Foundation

public enum RestWindowSource: String, Codable, Sendable {
    case weekday
    case weekend
    case globalFallback
    case defaultFallback
}

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

    /// Returns whether the whole interval is contained in this rest window.
    ///
    /// The end of a rest window is exclusive. Subtracting a small epsilon for
    /// the interval's end keeps an interval ending exactly at the window edge
    /// valid while still rejecting intervals that cross the edge.
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
