import Foundation

/// 智谱 LLM 供应商插件
actor ZhipuPlugin: SuperPlugin {
    static let id = "LLMProviderZhipu"
    static let displayName = "智谱"
    static let description = "Zhipu AI GLM Models"
    static let iconName = "sparkles"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        ZhipuProvider.self
    }
}
