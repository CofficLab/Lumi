import Foundation

/// 供应商+模型可用性状态。
enum LLMModelAvailabilityStatus: Equatable, Sendable {
    case unknown
    case checking
    case available
    case unavailable(String)
}

/// 单个模型的可用性信息。
struct LLMModelAvailabilityEntry: Identifiable, Equatable, Sendable {
    let modelId: String
    var status: LLMModelAvailabilityStatus = .unknown

    var id: String { modelId }
}

/// 单个供应商的可用性信息。
struct LLMProviderAvailabilityEntry: Identifiable, Equatable, Sendable {
    let providerId: String
    let displayName: String
    var models: [LLMModelAvailabilityEntry]

    var id: String { providerId }

    var availableModels: [String] {
        models.compactMap { $0.status == .available ? $0.modelId : nil }
    }

    var hasAvailableModels: Bool {
        !availableModels.isEmpty
    }
}
