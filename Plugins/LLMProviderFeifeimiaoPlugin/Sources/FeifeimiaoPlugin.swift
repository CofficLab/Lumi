import Foundation
import LumiCoreKit

/// Feifeimiao LLM 供应商插件
public actor FeifeimiaoPlugin: SuperPlugin {
    public static let shared = FeifeimiaoPlugin()
    public static let id = "LLMProviderFeifeimiao"
    public static let displayName = "Feifeimiao"
    public static let description = "Feifeimiao LLM API"
    public static let iconName = "wind"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        FeifeimiaoProvider.self
    }
}
