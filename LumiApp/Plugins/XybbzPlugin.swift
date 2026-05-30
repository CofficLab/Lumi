import AgentToolKit
import Foundation
import PluginLLMProviderXybbz

actor XybbzPlugin: SuperPlugin {
    static let shared = XybbzPlugin()
    static let id = PluginLLMProviderXybbz.XybbzPlugin.id
    static let displayName = PluginLLMProviderXybbz.XybbzPlugin.displayName
    static let description = PluginLLMProviderXybbz.XybbzPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderXybbz.XybbzPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderXybbz.XybbzPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderXybbz.XybbzPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderXybbz.XybbzProvider.self
    }
}
