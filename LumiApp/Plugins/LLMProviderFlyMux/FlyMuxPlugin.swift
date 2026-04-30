import Foundation

/// FlyMux LLM 供应商插件
actor FlyMuxPlugin: SuperPlugin {
    static let id = "LLMProviderFlyMux"
    static let displayName = "FlyMux"
    static let description = "FlyMux LLM Proxy"
    static let iconName = "antenna.radiowaves.left.and.right"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        FlyMuxProvider.self
    }
}
