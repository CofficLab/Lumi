import Foundation

/// OpenAI LLM 供应商插件
actor OpenAIPlugin: SuperPlugin {
    static let shared = OpenAIPlugin()
    static let id = "LLMProviderOpenAI"
    static let displayName = "OpenAI"
    static let description = "OpenAI GPT Models"
    static let iconName = "star.circle"
    static var category: PluginCategory { .llmProvider }
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        OpenAIProvider.self
    }
}
