import Foundation

/// 小米 LLM 供应商插件
actor XiaomiPlugin: SuperPlugin {
    static let shared = XiaomiPlugin()
    static let id = "LLMProviderXiaomi"
    static let displayName = "小米"
    static let description = "Xiaomi MiMo Models"
    static let iconName = "phone"
    static var category: PluginCategory { .llmProvider }
    static var order: Int { 10 }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        XiaomiProvider.self
    }
}
