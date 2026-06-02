import Foundation
import LumiCoreKit

/// OpenAI LLM 供应商插件
public actor OpenAIPlugin: SuperPlugin {
    public static let shared = OpenAIPlugin()
    public static let id = "LLMProviderOpenAI"
    public static let displayName = "OpenAI"
    public static let description = "OpenAI GPT Models"
    public static let iconName = "star.circle"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        OpenAIProvider.self
    }
}
