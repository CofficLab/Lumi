import AgentToolKit
import Foundation
import PluginLLMProviderOpenRouter

actor OpenRouterPlugin: SuperPlugin {
    static let shared = OpenRouterPlugin()
    static let id = PluginLLMProviderOpenRouter.OpenRouterPlugin.id
    static let displayName = PluginLLMProviderOpenRouter.OpenRouterPlugin.displayName
    static let description = PluginLLMProviderOpenRouter.OpenRouterPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderOpenRouter.OpenRouterPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderOpenRouter.OpenRouterPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderOpenRouter.OpenRouterPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderOpenRouter.OpenRouterProvider.self
    }
}
