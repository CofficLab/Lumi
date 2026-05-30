import AgentToolKit
import Foundation
import PluginLLMProviderDeepSeek

actor DeepSeekPlugin: SuperPlugin {
    static let shared = DeepSeekPlugin()
    static let id = PluginLLMProviderDeepSeek.DeepSeekPlugin.id
    static let displayName = PluginLLMProviderDeepSeek.DeepSeekPlugin.displayName
    static let description = PluginLLMProviderDeepSeek.DeepSeekPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderDeepSeek.DeepSeekPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderDeepSeek.DeepSeekPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderDeepSeek.DeepSeekPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderDeepSeek.DeepSeekProvider.self
    }
}
