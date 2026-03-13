import Foundation

/// Anthropic Claude LLM 供应商插件
///
/// 负责将 `AnthropicProvider` 注册到 `ProviderRegistry`。
final class AnthropicLLMPlugin: NSObject, SuperLLMProviderPlugin {

    static let enable: Bool = true
    static let order: Int = 90

    static func registerProviders(to registry: ProviderRegistry) {
        registry.register(AnthropicProvider.self)
    }
}

