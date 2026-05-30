import AgentToolKit
import Foundation
import PluginLLMProviderHappyCode

actor HappyCodePlugin: SuperPlugin {
    static let shared = HappyCodePlugin()
    static let id = PluginLLMProviderHappyCode.HappyCodePlugin.id
    static let displayName = PluginLLMProviderHappyCode.HappyCodePlugin.displayName
    static let description = PluginLLMProviderHappyCode.HappyCodePlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderHappyCode.HappyCodePlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderHappyCode.HappyCodePlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderHappyCode.HappyCodePlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderHappyCode.HappyCodeProvider.self
    }
}
