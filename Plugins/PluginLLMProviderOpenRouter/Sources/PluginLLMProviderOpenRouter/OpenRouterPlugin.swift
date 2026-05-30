import Foundation
import LumiCoreKit

/// OpenRouter LLM 供应商插件
///
/// 将 OpenRouterProvider 注册到 LLM 供应商注册表。
/// 通过 `SuperPlugin` 的 `llmProviderType()` 方法暴露供应商类型，
/// 由 AppPluginVM 统一发现并注册。
public actor OpenRouterPlugin: SuperPlugin {
    public static let shared = OpenRouterPlugin()
    public static let id = "LLMProviderOpenRouter"
    public static let displayName = "OpenRouter"
    public static let description = "Multi-Provider LLM Router"
    public static let iconName = "globe"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        OpenRouterProvider.self
    }
}
