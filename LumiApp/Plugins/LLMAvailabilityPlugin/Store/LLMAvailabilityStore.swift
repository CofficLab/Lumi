
typealias LLMAvailabilityStatus = LLMModelAvailabilityStatus
typealias LLMModelAvailability = LLMModelAvailabilityEntry
typealias LLMProviderAvailability = LLMProviderAvailabilityEntry
typealias LLMAvailabilityStore = LLMModelAvailabilityStore

/// LLM 可用性日志辅助（非 MainActor 隔离，供 Store / Checker 使用）
enum LLMAvailabilityLog: SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false
}
