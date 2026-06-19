import Foundation

struct ModelPerformanceStats: Sendable {
    let providerID: String
    let modelName: String
    var sampleCount: Int = 0
    var totalLatency: Double = 0
    var totalTTFT: Double = 0
    var ttftCount: Int = 0
    var totalInputTokens: Int = 0
    var inputTokenCount: Int = 0
    var totalOutputTokens: Int = 0
    var outputTokenCount: Int = 0
    var totalStreamingDuration: Double = 0
    var streamingDurationCount: Int = 0

    var avgLatency: Double {
        sampleCount > 0 ? totalLatency / Double(sampleCount) : 0
    }

    var avgTTFT: Double {
        ttftCount > 0 ? totalTTFT / Double(ttftCount) : 0
    }

    var avgTPS: Double {
        guard streamingDurationCount > 0, totalStreamingDuration > 0 else { return 0 }
        return Double(totalOutputTokens) / (totalStreamingDuration / 1000.0)
    }
}
