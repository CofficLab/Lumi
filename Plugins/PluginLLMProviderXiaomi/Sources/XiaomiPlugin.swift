import Foundation
import LumiCoreKit

/// 小米 LLM 供应商插件
public actor XiaomiPlugin: SuperPlugin {
    public static let shared = XiaomiPlugin()
    public static let id = "LLMProviderXiaomi"
    public static let displayName = "小米"
    public static let description = "Xiaomi MiMo Models"
    public static let iconName = "phone"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        XiaomiProvider.self
    }
}
