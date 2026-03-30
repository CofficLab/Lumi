import Foundation

/// 模型性能统计数据
public struct ModelPerformanceStats {
    let providerId: String
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

    var avgInputTokens: Int {
        inputTokenCount > 0 ? totalInputTokens / inputTokenCount : 0
    }

    var avgOutputTokens: Int {
        outputTokenCount > 0 ? totalOutputTokens / outputTokenCount : 0
    }

    var avgStreamingDuration: Double {
        streamingDurationCount > 0 ? totalStreamingDuration / Double(streamingDurationCount) : 0
    }

    /// 平均 TPS (Tokens Per Second)
    /// 计算方式：输出 token 数量 / 流式传输时间（秒）
    /// 注意：只统计同时有 outputTokens 和 streamingDuration 的消息
    var avgTPS: Double {
        guard streamingDurationCount > 0, totalStreamingDuration > 0 else { return 0 }
        return Double(totalOutputTokens) / (totalStreamingDuration / 1000.0) // 转换为秒
    }
}
