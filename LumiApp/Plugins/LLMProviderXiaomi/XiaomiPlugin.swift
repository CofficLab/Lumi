import Foundation

/// 小米 LLM 供应商插件
actor XiaomiPlugin: SuperPlugin {
    static let id = "LLMProviderXiaomi"
    static let displayName = "小米"
    static let description = "Xiaomi MiMo Models"
    static let iconName = "phone"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        XiaomiProvider.self
    }
}
