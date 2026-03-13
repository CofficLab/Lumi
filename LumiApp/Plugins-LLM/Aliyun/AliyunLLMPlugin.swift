import Foundation

/// 阿里云 DashScope LLM 供应商插件
///
/// 负责将 `AliyunProvider` 注册到 `ProviderRegistry`。
final class AliyunLLMPlugin: NSObject, SuperLLMProviderPlugin {

    static let enable: Bool = true
    static let order: Int = 130

    static func registerProviders(to registry: ProviderRegistry) {
        registry.register(AliyunProvider.self)
    }
}

