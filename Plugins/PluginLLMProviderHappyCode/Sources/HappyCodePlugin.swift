import Foundation
import LumiCoreKit

/// HappyCode LLM 供应商插件
public actor HappyCodePlugin: SuperPlugin {
    public static let shared = HappyCodePlugin()
    public static let id = "LLMProviderHappyCode"
    public static let displayName = "HappyCode"
    public static let description = "HappyCode LLM Gateway"
    public static let iconName = "party.popper"
    public static var order: Int { 12 }
    public static var category: PluginCategory { .llmProvider }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        HappyCodeProvider.self
    }
}