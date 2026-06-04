import Foundation

public struct IdleInferenceSnapshot: Codable, Sendable, Equatable {
    public let restWindow: RestWindow?
    public let observedDayCount: Int
    public let eventCount: Int
    public let lastActivityAt: Date?
    public let bucketScores: [Double]
    public let confidenceBreakdown: ConfidenceBreakdown

    public init(
        restWindow: RestWindow?,
        observedDayCount: Int,
        eventCount: Int,
        lastActivityAt: Date?,
        bucketScores: [Double],
        confidenceBreakdown: ConfidenceBreakdown
    ) {
        self.restWindow = restWindow
        self.observedDayCount = observedDayCount
        self.eventCount = eventCount
        self.lastActivityAt = lastActivityAt
        self.bucketScores = bucketScores
        self.confidenceBreakdown = confidenceBreakdown
    }

    public static func empty(generatedAt: Date = Date()) -> IdleInferenceSnapshot {
        IdleInferenceSnapshot(
            restWindow: nil,
            observedDayCount: 0,
            eventCount: 0,
            lastActivityAt: nil,
            bucketScores: Array(repeating: 0, count: 48),
            confidenceBreakdown: .zero
        )
    }
}

public struct ConfidenceBreakdown: Codable, Sendable, Equatable {
    public let dataCoverage: Double
    public let contrast: Double
    public let stability: Double

    public init(dataCoverage: Double, contrast: Double, stability: Double) {
        self.dataCoverage = dataCoverage
        self.contrast = contrast
        self.stability = stability
    }

    public static let zero = ConfidenceBreakdown(dataCoverage: 0, contrast: 0, stability: 0)
}
