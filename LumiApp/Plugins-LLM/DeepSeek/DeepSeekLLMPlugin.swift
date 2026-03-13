import Foundation

/// DeepSeek LLM 供应商插件
///
/// 负责将 `DeepSeekProvider` 注册到 `ProviderRegistry`。
final class DeepSeekLLMPlugin: NSObject, SuperLLMProviderPlugin {

    static let enable: Bool = true
    static let order: Int = 110

    static func registerProviders(to registry: ProviderRegistry) {
        registry.register(DeepSeekProvider.self)
    }
}

