import Foundation

struct RestWindow: Codable, Sendable, Equatable {
    let startMinuteOfDay: Int
    let endMinuteOfDay: Int
    let confidence: Double
    let source: RestWindowSource
    let generatedAt: Date

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if startMinuteOfDay <= endMinuteOfDay {
            return minute >= startMinuteOfDay && minute < endMinuteOfDay
        }
        return minute >= startMinuteOfDay || minute < endMinuteOfDay
    }
}

enum RestWindowSource: String, Codable, Sendable {
    case weekday
    case weekend
    case globalFallback
    case defaultFallback
}

enum IdleConfidenceLabel: String, Sendable {
    case learning
    case medium
    case high

    static func label(for confidence: Double, source: RestWindowSource) -> IdleConfidenceLabel {
        guard source != .defaultFallback, confidence >= 0.45 else { return .learning }
        return confidence >= 0.70 ? .high : .medium
    }
}
