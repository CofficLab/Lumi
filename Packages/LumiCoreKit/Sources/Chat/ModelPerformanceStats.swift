import Foundation

/// 单个 (provider, model) 在生命周期内累积的性能统计。
public struct ModelPerformanceStats: Sendable {
    public let providerID: String
    public let modelName: String
    public var sampleCount: Int = 0
    public var totalLatency: Double = 0
    public var totalTTFT: Double = 0
    public var ttftCount: Int = 0
    public var totalInputTokens: Int = 0
    public var inputTokenCount: Int = 0
    public var totalOutputTokens: Int = 0
    public var outputTokenCount: Int = 0
    public var totalStreamingDuration: Double = 0
    public var streamingDurationCount: Int = 0

    public init(providerID: String, modelName: String) {
        self.providerID = providerID
        self.modelName = modelName
    }

    public var avgLatency: Double {
        sampleCount > 0 ? totalLatency / Double(sampleCount) : 0
    }

    public var avgTTFT: Double {
        ttftCount > 0 ? totalTTFT / Double(ttftCount) : 0
    }

    public var avgTPS: Double {
        guard streamingDurationCount > 0, totalStreamingDuration > 0 else { return 0 }
        return Double(totalOutputTokens) / (totalStreamingDuration / 1000.0)
    }
}
