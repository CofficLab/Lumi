import Foundation
import LLMKit

public struct ModelSelectorStatsSnapshot: Sendable {
    public let detailedStats: [String: ModelPerformanceStats]
    public let frequentModels: [FrequentModelEntry]
    public let fastModels: [FastModelEntry]
}

public enum ModelSelectorStatsService {
    public static func loadSnapshot(
        providers: [LLMProviderInfo]
    ) async -> ModelSelectorStatsSnapshot {
        return ModelSelectorStatsSnapshot(
            detailedStats: [:],
            frequentModels: [],
            fastModels: []
        )
    }
}
