import Foundation

struct IdleInferenceSnapshot: Codable, Sendable, Equatable {
    let restWindow: RestWindow?
    let observedDayCount: Int
    let eventCount: Int
    let lastActivityAt: Date?
    let bucketScores: [Double]
    let confidenceBreakdown: ConfidenceBreakdown
}

struct ConfidenceBreakdown: Codable, Sendable, Equatable {
    let dataCoverage: Double
    let contrast: Double
    let stability: Double

    static let zero = ConfidenceBreakdown(dataCoverage: 0, contrast: 0, stability: 0)
}
