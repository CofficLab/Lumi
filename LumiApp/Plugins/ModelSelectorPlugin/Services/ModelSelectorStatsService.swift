import Foundation
import LLMKit
import SwiftData

struct ModelSelectorStatsSnapshot: Sendable {
    let detailedStats: [String: ModelPerformanceStats]
    let frequentModels: [FrequentModelEntry]
    let fastModels: [FastModelEntry]
}

enum ModelSelectorStatsService {
    static func loadSnapshot(
        modelContainer: ModelContainer,
        providers: [LLMProviderInfo]
    ) async -> ModelSelectorStatsSnapshot {
        await Task.detached(priority: .userInitiated) {
            buildSnapshot(modelContainer: modelContainer, providers: providers)
        }.value
    }

    private static func buildSnapshot(
        modelContainer: ModelContainer,
        providers: [LLMProviderInfo]
    ) -> ModelSelectorStatsSnapshot {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { msg in
                msg.metrics != nil && msg.providerId != nil && msg.modelName != nil
            }
        )

        guard let messageEntities = try? context.fetch(descriptor) else {
            AppLogger.core.error("🌐 ❌ 获取模型统计消息失败")
            return ModelSelectorStatsSnapshot(detailedStats: [:], frequentModels: [], fastModels: [])
        }

        var detailedStats: [String: ModelPerformanceStats] = [:]

        for entity in messageEntities {
            guard let providerId = entity.providerId,
                  let modelName = entity.modelName,
                  let metrics = entity.metrics,
                  let latency = metrics.latency else {
                continue
            }

            let key = "\(providerId)|\(modelName)"
            var stats = detailedStats[key] ?? ModelPerformanceStats(
                providerId: providerId,
                modelName: modelName,
                sampleCount: 0,
                totalLatency: 0,
                totalTTFT: 0,
                totalInputTokens: 0,
                totalOutputTokens: 0
            )

            stats.sampleCount += 1
            stats.totalLatency += latency

            if let ttft = metrics.timeToFirstToken {
                stats.totalTTFT += ttft
                stats.ttftCount += 1
            }

            if let inputTokens = metrics.inputTokens {
                stats.totalInputTokens += inputTokens
                stats.inputTokenCount += 1
            }

            if let outputTokens = metrics.outputTokens,
               let streamingDuration = metrics.streamingDuration {
                stats.totalOutputTokens += outputTokens
                stats.outputTokenCount += 1
                stats.totalStreamingDuration += streamingDuration
                stats.streamingDurationCount += 1
            }

            detailedStats[key] = stats
        }

        let providerMap = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })

        let frequentModels = detailedStats.values
            .filter { stat in
                guard let provider = providerMap[stat.providerId] else { return false }
                return provider.availableModels.contains(stat.modelName)
            }
            .map { stat -> FrequentModelEntry in
                let provider = providerMap[stat.providerId]
                return FrequentModelEntry(
                    id: "\(stat.providerId)|\(stat.modelName)",
                    providerId: stat.providerId,
                    providerDisplayName: provider?.displayName ?? stat.providerId,
                    modelName: stat.modelName,
                    useCount: stat.sampleCount,
                    lastUsedAt: Date()
                )
            }
            .sorted { $0.useCount > $1.useCount }

        let fastModels = detailedStats.values
            .filter { stat in
                stat.avgTPS > 0 && stat.sampleCount > 0
            }
            .filter { stat in
                guard let provider = providerMap[stat.providerId] else { return false }
                return provider.availableModels.contains(stat.modelName)
            }
            .map { stat -> FastModelEntry in
                let provider = providerMap[stat.providerId]
                return FastModelEntry(
                    id: "\(stat.providerId)|\(stat.modelName)",
                    providerId: stat.providerId,
                    providerDisplayName: provider?.displayName ?? stat.providerId,
                    modelName: stat.modelName,
                    avgTPS: stat.avgTPS,
                    sampleCount: stat.sampleCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.avgTPS == rhs.avgTPS {
                    return lhs.sampleCount > rhs.sampleCount
                }
                return lhs.avgTPS > rhs.avgTPS
            }

        return ModelSelectorStatsSnapshot(
            detailedStats: detailedStats,
            frequentModels: Array(frequentModels.prefix(10)),
            fastModels: Array(fastModels.prefix(10))
        )
    }
}
