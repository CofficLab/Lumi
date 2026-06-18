import Foundation

public enum LumiMessagePerformanceMetadata {
    public static let latencyKey = "latencyMs"
    public static let timeToFirstTokenKey = "timeToFirstTokenMs"
    public static let streamingDurationKey = "streamingDurationMs"

    public static func metadata(
        latencyMs: Double?,
        timeToFirstTokenMs: Double?,
        streamingDurationMs: Double?
    ) -> [String: String] {
        var metadata: [String: String] = [:]
        if let latencyMs {
            metadata[latencyKey] = String(latencyMs)
        }
        if let timeToFirstTokenMs {
            metadata[timeToFirstTokenKey] = String(timeToFirstTokenMs)
        }
        if let streamingDurationMs {
            metadata[streamingDurationKey] = String(streamingDurationMs)
        }
        return metadata
    }
}

public extension LumiChatMessage {
    var latencyMs: Double? {
        metadata[LumiMessagePerformanceMetadata.latencyKey].flatMap(Double.init)
    }

    var timeToFirstTokenMs: Double? {
        metadata[LumiMessagePerformanceMetadata.timeToFirstTokenKey].flatMap(Double.init)
    }

    var streamingDurationMs: Double? {
        metadata[LumiMessagePerformanceMetadata.streamingDurationKey].flatMap(Double.init)
    }

    /// Tokens per second for this message when output tokens and streaming duration are available.
    var tokensPerSecond: Double? {
        guard let outputTokens = outputTokenCount,
              let streamingDurationMs,
              streamingDurationMs > 0 else {
            return nil
        }
        return Double(outputTokens) / (streamingDurationMs / 1000.0)
    }
}
