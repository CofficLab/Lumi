import AgentToolKit
import Foundation
import PluginLLMProviderXiaomi

actor XiaomiPlugin: SuperPlugin {
    static let shared = XiaomiPlugin()
    static let id = PluginLLMProviderXiaomi.XiaomiPlugin.id
    static let displayName = PluginLLMProviderXiaomi.XiaomiPlugin.displayName
    static let description = PluginLLMProviderXiaomi.XiaomiPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderXiaomi.XiaomiPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderXiaomi.XiaomiPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderXiaomi.XiaomiPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderXiaomi.XiaomiProvider.self
    }
}
