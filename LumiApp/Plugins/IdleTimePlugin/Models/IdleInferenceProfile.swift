import Foundation

enum IdleInferenceProfile: Sendable {
    case weekday
    case weekend
    case global

    var source: RestWindowSource {
        switch self {
        case .weekday:
            return .weekday
        case .weekend:
            return .weekend
        case .global:
            return .globalFallback
        }
    }

    var targetObservedDays: Int {
        switch self {
        case .weekday, .global:
            return 14
        case .weekend:
            return 6
        }
    }
}
