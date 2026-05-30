import AgentToolKit
import Foundation
import PluginLLMProviderFreeModel

actor FreeModelPlugin: SuperPlugin {
    static let shared = FreeModelPlugin()
    static let id = PluginLLMProviderFreeModel.FreeModelPlugin.id
    static let displayName = PluginLLMProviderFreeModel.FreeModelPlugin.displayName
    static let description = PluginLLMProviderFreeModel.FreeModelPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderFreeModel.FreeModelPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderFreeModel.FreeModelPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderFreeModel.FreeModelPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderFreeModel.FreeModelProvider.self
    }
}
