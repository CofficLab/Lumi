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

    public init(
        startMinuteOfDay: Int,
        endMinuteOfDay: Int,
        confidence: Double,
        source: RestWindowSource,
        generatedAt: Date
    ) {
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
}

public enum IdleConfidenceLabel: Sendable, Equatable {
    case learning
    case medium
    case high

    public static func label(for confidence: Double, source: RestWindowSource) -> IdleConfidenceLabel {
        if source == .defaultFallback || confidence < 0.45 {
            return .learning
        }
        if confidence >= 0.70 {
            return .high
        }
        return .medium
    }
}
