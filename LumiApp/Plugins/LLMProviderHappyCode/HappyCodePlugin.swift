import Foundation

/// HappyCode LLM 供应商插件
actor HappyCodePlugin: SuperPlugin {
    static let shared = HappyCodePlugin()
    static let id = "LLMProviderHappyCode"
    static let displayName = "HappyCode"
    static let description = "HappyCode LLM Gateway"
    static let iconName = "party.popper"
    static var order: Int { 12 }
    static var category: PluginCategory { .llmProvider }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        HappyCodeProvider.self
    }
}