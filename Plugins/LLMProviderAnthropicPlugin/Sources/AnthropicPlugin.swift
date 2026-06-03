import Foundation
import LumiCoreKit

/// Anthropic LLM 供应商插件
public actor AnthropicPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = AnthropicPlugin()
    public static let id = "LLMProviderAnthropic"
    public static let displayName = "Anthropic"
    public static let description = "Claude AI by Anthropic"
    public static let iconName = "brain"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        AnthropicProvider.self
    }
}
