import Foundation
import KernelLumi

extension LumiChatMessage {
    /// Duration used for the user-facing speed metric.
    ///
    /// `streamingDurationMs` starts at the first token. When a provider buffers
    /// the response and delivers it in one chunk, that value can be nearly zero.
    /// The full request latency better represents the speed perceived by the
    /// user in that case.
    var conversationSpeedDurationMs: Double? {
        let streamingDuration = streamingDurationMs
            ?? Double(metadata["streamingDurationMs"] ?? "")
        let latency = latencyMs
            ?? Double(metadata["latencyMs"] ?? "")

        switch (streamingDuration, latency) {
        case let (streaming?, latency?) where streaming > 0 && latency > 0:
            return max(streaming, latency)
        case let (streaming?, _) where streaming > 0:
            return streaming
        case let (_, latency?) where latency > 0:
            return latency
        default:
            return nil
        }
    }

    var conversationSpeedTokensPerSecond: Double? {
        let outputTokens = outputTokenCount
            ?? Int(metadata["outputTokens"] ?? "")
        guard let outputTokens,
              let durationMs = conversationSpeedDurationMs,
              durationMs > 0 else {
            return nil
        }
        return Double(outputTokens) / (durationMs / 1000.0)
    }
}
