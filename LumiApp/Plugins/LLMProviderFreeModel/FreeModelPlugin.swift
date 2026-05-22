import Foundation

/// FreeModel LLM 供应商插件
actor FreeModelPlugin: SuperPlugin {
    static let shared = FreeModelPlugin()
    static let id = "LLMProviderFreeModel"
    static let displayName = "FreeModel"
    static let description = "FreeModel LLM Gateway"
    static let iconName = "bolt.horizontal"
    static var category: PluginCategory { .llmProvider }
    static var order: Int { 11 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        FreeModelProvider.self
    }
}
