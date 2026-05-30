import AgentToolKit
import Foundation
import PluginLLMProviderFeifeimiao

actor FeifeimiaoPlugin: SuperPlugin {
    static let shared = FeifeimiaoPlugin()
    static let id = PluginLLMProviderFeifeimiao.FeifeimiaoPlugin.id
    static let displayName = PluginLLMProviderFeifeimiao.FeifeimiaoPlugin.displayName
    static let description = PluginLLMProviderFeifeimiao.FeifeimiaoPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderFeifeimiao.FeifeimiaoPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderFeifeimiao.FeifeimiaoPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderFeifeimiao.FeifeimiaoPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderFeifeimiao.FeifeimiaoProvider.self
    }
}
