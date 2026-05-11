import Foundation

/// Sub2Api LLM 供应商插件
actor Sub2ApiPlugin: SuperPlugin {
    static let shared = Sub2ApiPlugin()
    static let id = "LLMProviderSub2Api"
    static let displayName = "Sub2Api"
    static let description = "Sub2Api LLM Gateway"
    static let iconName = "server.rack"
    static var order: Int { 11 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        Sub2ApiProvider.self
    }
}
