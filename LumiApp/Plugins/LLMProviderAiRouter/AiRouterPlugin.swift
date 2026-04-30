import Foundation

/// AiRouter LLM 供应商插件
actor AiRouterPlugin: SuperPlugin {
    static let id = "LLMProviderAiRouter"
    static let displayName = "AiRouter"
    static let description = "AiRouter LLM Gateway"
    static let iconName = "arrow.triangle.branch"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        AiRouterProvider.self
    }
}
