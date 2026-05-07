import Foundation

/// OpenRouter LLM 供应商插件
///
/// 将 OpenRouterProvider 注册到 LLM 供应商注册表。
/// 通过 `SuperPlugin` 的 `llmProviderType()` 方法暴露供应商类型，
/// 由 PluginVM 统一发现并注册。
actor OpenRouterPlugin: SuperPlugin {
    static let id = "LLMProviderOpenRouter"
    static let displayName = "OpenRouter"
    static let description = "Multi-Provider LLM Router"
    static let iconName = "globe"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        OpenRouterProvider.self
    }
}
