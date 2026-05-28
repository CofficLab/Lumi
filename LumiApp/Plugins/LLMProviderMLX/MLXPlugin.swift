import Foundation

/// MLX 本地 LLM 供应商插件
actor MLXPlugin: SuperPlugin {
    static let shared = MLXPlugin()
    static let id = "LLMProviderMLX"
    static let displayName = "MLX"
    static let description = "Local LLM via Apple MLX"
    static let iconName = "desktopcomputer"
    static var order: Int { 10 }
    static var category: PluginCategory { .llmProvider }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        MLXProvider.self
    }
}
