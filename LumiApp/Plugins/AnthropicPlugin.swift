import AgentToolKit
import Foundation
import PluginLLMProviderAnthropic

actor AnthropicPlugin: SuperPlugin {
    static let shared = AnthropicPlugin()
    static let id = PluginLLMProviderAnthropic.AnthropicPlugin.id
    static let displayName = PluginLLMProviderAnthropic.AnthropicPlugin.displayName
    static let description = PluginLLMProviderAnthropic.AnthropicPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderAnthropic.AnthropicPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderAnthropic.AnthropicPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderAnthropic.AnthropicPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderAnthropic.AnthropicProvider.self
    }
}
