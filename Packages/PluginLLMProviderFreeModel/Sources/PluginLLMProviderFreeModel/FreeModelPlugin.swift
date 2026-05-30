import Foundation
import LumiCoreKit

/// FreeModel LLM 供应商插件
public actor FreeModelPlugin: SuperPlugin {
    public static let shared = FreeModelPlugin()
    public static let id = "LLMProviderFreeModel"
    public static let displayName = "FreeModel"
    public static let description = "FreeModel LLM Gateway"
    public static let iconName = "bolt.horizontal"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 11 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        FreeModelProvider.self
    }
}
