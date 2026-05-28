import Foundation

/// AiRouter LLM 供应商插件
actor AiRouterPlugin: SuperPlugin {
    static let shared = AiRouterPlugin()
    static let id = "LLMProviderAiRouter"
    static let displayName = "AiRouter"
    static let description = "AiRouter LLM Gateway"
    static let iconName = "arrow.triangle.branch"
    static var category: PluginCategory { .llmProvider }
    static var order: Int { 10 }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        AiRouterProvider.self
    }
}
