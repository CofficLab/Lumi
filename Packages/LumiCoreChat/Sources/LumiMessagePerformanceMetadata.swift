import Foundation
import LumiCoreMessage

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
    /// Tokens per second for this message when output tokens and streaming duration are available.
    var tokensPerSecond: Double? {
        guard let outputTokens = outputTokenCount,
              let duration = streamingDurationMs,
              duration > 0 else {
            return nil
        }
        return Double(outputTokens) / (Double(duration) / 1000.0)
    }
}