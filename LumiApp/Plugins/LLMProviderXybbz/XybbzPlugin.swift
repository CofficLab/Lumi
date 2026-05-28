import Foundation

/// Xybbz LLM 供应商插件
actor XybbzPlugin: SuperPlugin {
    static let shared = XybbzPlugin()
    static let id = "LLMProviderXybbz"
    static let displayName = "Xybbz"
    static let description = "Xybbz LLM Gateway"
    static let iconName = "server.rack"
    static var order: Int { 11 }
    static var category: PluginCategory { .llmProvider }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        XybbzProvider.self
    }
}
