import Foundation
import LumiCoreKit

/// LPgpt LLM 供应商插件
public actor LPgptPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = LPgptPlugin()
    public static let id = "LLMProviderLPgpt"
    public static let displayName = "LPgpt"
    public static let description = "LPgpt LLM Gateway"
    public static let iconName = "globe"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 12 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        LPgptProvider.self
    }
}
