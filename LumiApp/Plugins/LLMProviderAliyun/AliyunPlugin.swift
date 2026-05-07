import Foundation

/// 阿里云 LLM 供应商插件
actor AliyunPlugin: SuperPlugin {
    static let id = "LLMProviderAliyun"
    static let displayName = "阿里云"
    static let description = "Aliyun Qwen Models"
    static let iconName = "cloud"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        AliyunProvider.self
    }
}
