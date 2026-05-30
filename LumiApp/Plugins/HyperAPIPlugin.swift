import AgentToolKit
import Foundation
import PluginLLMProviderHyperAPI

actor HyperAPIPlugin: SuperPlugin {
    static let shared = HyperAPIPlugin()
    static let id = PluginLLMProviderHyperAPI.HyperAPIPlugin.id
    static let displayName = PluginLLMProviderHyperAPI.HyperAPIPlugin.displayName
    static let description = PluginLLMProviderHyperAPI.HyperAPIPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderHyperAPI.HyperAPIPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderHyperAPI.HyperAPIPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderHyperAPI.HyperAPIPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderHyperAPI.HyperAPIProvider.self
    }
}
