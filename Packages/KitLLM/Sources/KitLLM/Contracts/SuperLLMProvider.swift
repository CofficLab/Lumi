import Foundation

/// 可注册进 `LLMProviderManagerProviding` 的单个 LLM 供应商。
@MainActor
public protocol SuperLLMProvider: AnyObject, Sendable {
    /// 供应商标识（通常等于 `providerInfo.id`）。
    var providerID: String { get }

    /// 供应商元数据：`providerInfo.id` 即注册表 key。
    var providerInfo: LLMProviderInfo { get }

    /// 发送非流式 LLM 完成请求。
    func complete(_ request: LLMRequest) async throws -> LLMResponse

    /// 是否已配置 API Key（本地供应商无需 Key，默认 `true`）。
    func hasApiKey() -> Bool

    /// 读取 API Key（未配置返回空串）。
    func getApiKey() -> String

    /// 写入 API Key。
    func setApiKey(_ apiKey: String)

    /// 删除 API Key。
    func removeApiKey()
}

// MARK: - Default implementation（本地供应商无 Key 语义）

public extension SuperLLMProvider {
    func hasApiKey() -> Bool { true }
    func getApiKey() -> String { "" }
    func setApiKey(_ apiKey: String) {}
    func removeApiKey() {}
}

/// `SuperLLMProvider` 的历史别名，保持下游测试兼容。
public typealias ManagedLLMProvider = SuperLLMProvider
