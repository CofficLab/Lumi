import Foundation

/// GoatPlan 远程模型源的端点配置。
///
/// - 认证：`/provider/v1/models` 端点公开可读，无需鉴权（也避免后台刷新读 Keychain）。
struct RemoteModelSource: Sendable, Equatable {
    /// 远程模型列表端点。
    let endpoint: URL

    /// API Key 在 Keychain 中的存储 key；非空时以 `Bearer` 注入认证头。
    /// `nil` 表示端点无需认证。
    let apiKeyStorageKey: String?

    init(endpoint: URL, apiKeyStorageKey: String? = nil) {
        self.endpoint = endpoint
        self.apiKeyStorageKey = apiKeyStorageKey
    }
}
