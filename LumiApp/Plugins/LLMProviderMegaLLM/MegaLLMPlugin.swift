import Foundation

/// MegaLLM LLM 供应商插件
actor MegaLLMPlugin: SuperPlugin {
    static let id = "LLMProviderMegaLLM"
    static let displayName = "MegaLLM"
    static let description = "MegaLLM Multi-Provider"
    static let iconName = "server.rack"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        MegaLLMProvider.self
    }
}
