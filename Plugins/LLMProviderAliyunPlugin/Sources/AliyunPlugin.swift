import Foundation
import LumiCoreKit

/// 阿里云 LLM 供应商插件
public actor AliyunPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = AliyunPlugin()
    public static let id = "LLMProviderAliyun"
    public static let displayName = "阿里云"
    public static let description = "Aliyun Qwen Models"
    public static let iconName = "cloud"
    public static var order: Int { 10 }
    public static var category: PluginCategory { .llmProvider }

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        AliyunProvider.self
    }
}
