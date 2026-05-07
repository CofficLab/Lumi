import Foundation

/// HyperAPI LLM 供应商插件
actor HyperAPIPlugin: SuperPlugin {
    static let id = "LLMProviderHyperAPI"
    static let displayName = "HyperAPI"
    static let description = "HyperAPI LLM Gateway"
    static let iconName = "bolt.horizontal"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        HyperAPIProvider.self
    }
}
