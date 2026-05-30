import AgentToolKit
import Foundation
import PluginLLMProviderLPgpt

actor LPgptPlugin: SuperPlugin {
    static let shared = LPgptPlugin()
    static let id = PluginLLMProviderLPgpt.LPgptPlugin.id
    static let displayName = PluginLLMProviderLPgpt.LPgptPlugin.displayName
    static let description = PluginLLMProviderLPgpt.LPgptPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderLPgpt.LPgptPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderLPgpt.LPgptPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderLPgpt.LPgptPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderLPgpt.LPgptProvider.self
    }
}
