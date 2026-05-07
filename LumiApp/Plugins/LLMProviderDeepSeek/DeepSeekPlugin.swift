import Foundation

/// DeepSeek LLM 供应商插件
actor DeepSeekPlugin: SuperPlugin {
    static let id = "LLMProviderDeepSeek"
    static let displayName = "DeepSeek"
    static let description = "DeepSeek AI"
    static let iconName = "waveform.path"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        DeepSeekProvider.self
    }
}
