import Foundation

/// 供应商注册协议
///
/// 允许供应商类型自行注册到注册表。
/// 注册表的具体实现由内核提供（LLMProviderRegistry），
/// 此协议仅约束供应商侧的注册入口。
public protocol SuperProviderRegistrant {
    /// 注册到指定的注册表
    static func register(to registry: any LLMProviderRegistering)
}

/// 供应商注册表抽象
///
/// 将注册能力抽象为协议，使 PluginKit 不依赖内核具体的 LLMProviderRegistry 实现。
/// 内核的 LLMProviderRegistry 只需遵循此协议即可。
public protocol LLMProviderRegistering: Sendable {
    func register<T: SuperLLMProvider>(_ providerType: T.Type)
    func createProvider(id: String) -> (any SuperLLMProvider)?
}
