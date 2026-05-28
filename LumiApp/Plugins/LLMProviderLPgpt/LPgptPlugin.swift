import Foundation

/// LPgpt LLM 供应商插件
actor LPgptPlugin: SuperPlugin {
    static let shared = LPgptPlugin()
    static let id = "LLMProviderLPgpt"
    static let displayName = "LPgpt"
    static let description = "LPgpt LLM Gateway"
    static let iconName = "globe"
    static var category: PluginCategory { .llmProvider }
    static var order: Int { 12 }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        LPgptProvider.self
    }
}
