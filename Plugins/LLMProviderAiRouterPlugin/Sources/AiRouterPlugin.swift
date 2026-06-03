import Foundation
import LumiCoreKit

/// AiRouter LLM 供应商插件
public actor AiRouterPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = AiRouterPlugin()
    public static let id = "LLMProviderAiRouter"
    public static let displayName = "AiRouter"
    public static let description = "AiRouter LLM Gateway"
    public static let iconName = "arrow.triangle.branch"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        AiRouterProvider.self
    }
}
