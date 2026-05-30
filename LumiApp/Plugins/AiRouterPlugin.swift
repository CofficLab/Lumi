import AgentToolKit
import Foundation
import PluginLLMProviderAiRouter

actor AiRouterPlugin: SuperPlugin {
    static let shared = AiRouterPlugin()
    static let id = PluginLLMProviderAiRouter.AiRouterPlugin.id
    static let displayName = PluginLLMProviderAiRouter.AiRouterPlugin.displayName
    static let description = PluginLLMProviderAiRouter.AiRouterPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderAiRouter.AiRouterPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderAiRouter.AiRouterPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderAiRouter.AiRouterPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderAiRouter.AiRouterProvider.self
    }
}
