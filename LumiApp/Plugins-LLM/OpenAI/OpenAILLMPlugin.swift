import Foundation

/// OpenAI LLM 供应商插件
///
/// 负责将 `OpenAIProvider` 注册到 `ProviderRegistry`。
final class OpenAILLMPlugin: NSObject, SuperLLMProviderPlugin {

    static let enable: Bool = true
    static let order: Int = 100

    static func registerProviders(to registry: ProviderRegistry) {
        registry.register(OpenAIProvider.self)
    }
}

