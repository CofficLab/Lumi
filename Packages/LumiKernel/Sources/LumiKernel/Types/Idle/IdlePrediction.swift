import Foundation

/// A prediction that a requested interval falls inside the inferred rest window.
public struct IdlePrediction: Codable, Sendable, Equatable {
    public let checkedAt: Date
    public let duration: TimeInterval
    public let isLikelyIdle: Bool
    public let confidence: Double
    public let restWindow: RestWindow?

    public init(
        checkedAt: Date,
        duration: TimeInterval,
        isLikelyIdle: Bool,
        confidence: Double,
        restWindow: RestWindow?
    ) {
        self.checkedAt = checkedAt
        self.duration = duration
        self.isLikelyIdle = isLikelyIdle
        self.confidence = confidence
        self.restWindow = restWindow
    }
}
