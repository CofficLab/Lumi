import Foundation

/// LLM 供应商远程模型源的端点配置。
///
/// 由实现 `LLMModelListProviding` 的供应商在注册时声明；只有
/// `usesRemoteModelList == true` 的供应商才需要配置。
///
/// - 认证：优先复用供应商 `LLMProviderInfo.apiKeyStorageKey` 以
///   `Bearer` 方式注入；不需要认证的端点用 `auth == nil`。
public struct RemoteModelSource: Sendable, Equatable {
    /// 远程模型列表端点，如 `https://api.commandcode.ai/provider/v1/models`。
    public let endpoint: URL

    /// API Key 在 Keychain 中的存储 key；非空时以 `Bearer` 注入认证头。
    /// `nil` 表示端点无需认证。
    public let apiKeyStorageKey: String?

    public init(endpoint: URL, apiKeyStorageKey: String? = nil) {
        self.endpoint = endpoint
        self.apiKeyStorageKey = apiKeyStorageKey
    }
}