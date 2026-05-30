import AgentToolKit
import Foundation
import PluginLLMProviderFlyMux

actor FlyMuxPlugin: SuperPlugin {
    static let shared = FlyMuxPlugin()
    static let id = PluginLLMProviderFlyMux.FlyMuxPlugin.id
    static let displayName = PluginLLMProviderFlyMux.FlyMuxPlugin.displayName
    static let description = PluginLLMProviderFlyMux.FlyMuxPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderFlyMux.FlyMuxPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderFlyMux.FlyMuxPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderFlyMux.FlyMuxPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderFlyMux.FlyMuxProvider.self
    }
}
