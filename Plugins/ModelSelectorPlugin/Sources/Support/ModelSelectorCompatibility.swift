import Foundation
@_exported import LLMAvailabilityPlugin

public struct ModelPerformanceStats: Sendable {
    public let providerId: String
    public let modelName: String
    public var sampleCount: Int
    public var avgLatency: Double
    public var avgTTFT: Double
    public var avgInputTokens: Int
    public var avgOutputTokens: Int
    public var avgTPS: Double

    public init(
        providerId: String,
        modelName: String,
        sampleCount: Int = 0,
        avgLatency: Double = 0,
        avgTTFT: Double = 0,
        avgInputTokens: Int = 0,
        avgOutputTokens: Int = 0,
        avgTPS: Double = 0
    ) {
        self.providerId = providerId
        self.modelName = modelName
        self.sampleCount = sampleCount
        self.avgLatency = avgLatency
        self.avgTTFT = avgTTFT
        self.avgInputTokens = avgInputTokens
        self.avgOutputTokens = avgOutputTokens
        self.avgTPS = avgTPS
    }
}
