import Foundation

/// Zhipu AI (智谱) LLM 供应商插件
///
/// 负责将 `ZhipuProvider` 注册到 `ProviderRegistry`。
final class ZhipuLLMPlugin: NSObject, SuperLLMProviderPlugin {

    static let enable: Bool = true
    static let order: Int = 120

    static func registerProviders(to registry: ProviderRegistry) {
        registry.register(ZhipuProvider.self)
    }
}

