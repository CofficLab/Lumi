import Foundation

/// Feifeimiao LLM 供应商插件
actor FeifeimiaoPlugin: SuperPlugin {
    static let shared = FeifeimiaoPlugin()
    static let id = "LLMProviderFeifeimiao"
    static let displayName = "Feifeimiao"
    static let description = "Feifeimiao LLM API"
    static let iconName = "wind"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        FeifeimiaoProvider.self
    }
}
