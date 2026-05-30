import Foundation
import LumiCoreKit

/// HyperAPI LLM 供应商插件
public actor HyperAPIPlugin: SuperPlugin {
    public static let shared = HyperAPIPlugin()
    public static let id = "LLMProviderHyperAPI"
    public static let displayName = "HyperAPI"
    public static let description = "HyperAPI LLM Gateway"
    public static let iconName = "bolt.horizontal"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        HyperAPIProvider.self
    }
}
