import Foundation

/// Anthropic LLM 供应商插件
actor AnthropicPlugin: SuperPlugin {
    static let id = "LLMProviderAnthropic"
    static let displayName = "Anthropic"
    static let description = "Claude AI by Anthropic"
    static let iconName = "brain"
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        AnthropicProvider.self
    }
}
