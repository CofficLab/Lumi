import Foundation
import LumiCoreKit

struct ModelSelectorStatsSnapshot: Sendable {
    let detailedStats: [String: ModelPerformanceStats]
    let fastModels: [(provider: LumiLLMProviderInfo, model: String, avgTPS: Double, sampleCount: Int)]
}

enum ModelSelectorStatsService {
    static func buildSnapshot(
        messages: [LumiChatMessage],
        providers: [LumiLLMProviderInfo]
    ) -> ModelSelectorStatsSnapshot {
        var detailedStats: [String: ModelPerformanceStats] = [:]

        for message in messages where message.role == .assistant {
            guard let providerID = message.providerID,
                  let modelName = message.modelName,
                  let latencyMs = message.latencyMs else {
                continue
            }

            let key = "\(providerID)|\(modelName)"
            var stats = detailedStats[key] ?? ModelPerformanceStats(
                providerID: providerID,
                modelName: modelName
            )

            stats.sampleCount += 1
            stats.totalLatency += latencyMs

            if let ttft = message.timeToFirstTokenMs {
                stats.totalTTFT += ttft
                stats.ttftCount += 1
            }

            if let inputTokens = message.inputTokenCount {
                stats.totalInputTokens += inputTokens
                stats.inputTokenCount += 1
            }

            if let outputTokens = message.outputTokenCount,
               let streamingDurationMs = message.streamingDurationMs {
                stats.totalOutputTokens += outputTokens
                stats.outputTokenCount += 1
                stats.totalStreamingDuration += streamingDurationMs
                stats.streamingDurationCount += 1
            }

            detailedStats[key] = stats
        }

        let providerMap = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
        let fastModels = detailedStats.values
            .filter { $0.avgTPS > 0 && $0.sampleCount > 0 }
            .compactMap { stat -> (provider: LumiLLMProviderInfo, model: String, avgTPS: Double, sampleCount: Int)? in
                guard let provider = providerMap[stat.providerID],
                      provider.availableModels.contains(stat.modelName) else {
                    return nil
                }
                return (provider, stat.modelName, stat.avgTPS, stat.sampleCount)
            }
            .sorted { lhs, rhs in
                if lhs.avgTPS == rhs.avgTPS {
                    return lhs.sampleCount > rhs.sampleCount
                }
                return lhs.avgTPS > rhs.avgTPS
            }

        return ModelSelectorStatsSnapshot(
            detailedStats: detailedStats,
            fastModels: Array(fastModels.prefix(10))
        )
    }
}
