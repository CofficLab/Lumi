import Foundation
import LumiCoreKit

/// DeepSeek LLM 供应商插件
public actor DeepSeekPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = DeepSeekPlugin()
    public static let id = "LLMProviderDeepSeek"
    public static let displayName = "DeepSeek"
    public static let description = "DeepSeek AI"
    public static let iconName = "waveform.path"
    public static var order: Int { 10 }
    public static var category: PluginCategory { .llmProvider }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        DeepSeekProvider.self
    }
}
