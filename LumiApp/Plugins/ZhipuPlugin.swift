import AgentToolKit
import Foundation
import SwiftUI
import PluginLLMProviderZhipu

actor ZhipuPlugin: SuperPlugin {
    static let shared = ZhipuPlugin()
    static let id = PluginLLMProviderZhipu.ZhipuPlugin.id
    static let displayName = PluginLLMProviderZhipu.ZhipuPlugin.displayName
    static let description = PluginLLMProviderZhipu.ZhipuPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderZhipu.ZhipuPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderZhipu.ZhipuPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderZhipu.ZhipuPlugin.order }

    nonisolated func onRegister() {
        PluginLLMProviderZhipu.ZhipuPlugin.configuration = .init(apiKeyProvider: {
            APIKeyStore.shared.string(forKey: "DevAssistant_ApiKey_Zhipu") ?? ""
        })
    }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderZhipu.ZhipuProvider.self
    }

    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        PluginLLMProviderZhipu.ZhipuPlugin.shared.addStatusBarTrailingView(context: context)
    }
}
