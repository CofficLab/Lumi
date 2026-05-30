import AgentToolKit
import Foundation
import PluginLLMProviderAliyun

actor AliyunPlugin: SuperPlugin {
    static let shared = AliyunPlugin()
    static let id = PluginLLMProviderAliyun.AliyunPlugin.id
    static let displayName = PluginLLMProviderAliyun.AliyunPlugin.displayName
    static let description = PluginLLMProviderAliyun.AliyunPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginLLMProviderAliyun.AliyunPlugin.description(for: language)
    }
    static let iconName = PluginLLMProviderAliyun.AliyunPlugin.iconName
    static var category: PluginCategory { .llmProvider }
    static var order: Int { PluginLLMProviderAliyun.AliyunPlugin.order }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        PluginLLMProviderAliyun.AliyunProvider.self
    }
}
