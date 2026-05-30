import AgentToolKit
import Foundation
import PluginLLMProviderOpenAI

actor OpenAIPlugin: SuperPlugin {
    static let shared = OpenAIPlugin()
    static let id = PluginLLMProviderOpenAI.OpenAIPlugin.id
    static let displayName = PluginLLMProviderOpenAI.OpenAIPlugin.displayName
    static let description = PluginLLMProviderOpenAI.OpenAIPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderOpenAI.OpenAIPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderOpenAI.OpenAIPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderOpenAI.OpenAIPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderOpenAI.OpenAIProvider.self
    }
}
