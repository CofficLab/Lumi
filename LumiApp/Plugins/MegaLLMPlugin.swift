import AgentToolKit
import Foundation
import PluginLLMProviderMegaLLM

actor MegaLLMPlugin: SuperPlugin {
    static let shared = MegaLLMPlugin()
    static let id = PluginLLMProviderMegaLLM.MegaLLMPlugin.id
    static let displayName = PluginLLMProviderMegaLLM.MegaLLMPlugin.displayName
    static let description = PluginLLMProviderMegaLLM.MegaLLMPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderMegaLLM.MegaLLMPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderMegaLLM.MegaLLMPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderMegaLLM.MegaLLMPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderMegaLLM.MegaLLMProvider.self
    }
}
