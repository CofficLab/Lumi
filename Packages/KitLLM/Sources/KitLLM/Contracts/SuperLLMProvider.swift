import Foundation

/// 可注册进 `LLMProviderManagerProviding` 的单个 LLM 供应商。
@MainActor
public protocol SuperLLMProvider: AnyObject, Sendable {
    /// 供应商标识（通常等于 `providerInfo.id`）。
    var providerID: String { get }

    /// 供应商元数据：`providerInfo.id` 即注册表 key。
    var providerInfo: LLMProviderInfo { get }

    /// 当前可用模型池。
    ///
    /// 由每个供应商**自行决定**获取策略：
    /// - 静态供应商：默认实现返回 `providerInfo.models`（硬编码）。
    /// - 远程供应商：override 后返回「远程快照 / 缓存 / 静态基线」的合并结果。
    ///
    /// 实现约定：**绝不返回空列表**覆盖已有模型（缓存优先、基线兜底）。
    var availableModels: [LLMModelInfo] { get }

    /// 主动刷新模型列表。
    ///
    /// 由每个供应商自行决定实现：静态型是空操作；远程型拉取模型端点并更新
    /// 内部快照 / 缓存。拉取失败抛错，调用方保留旧模型池。
    func refreshModels() async throws

    /// 供应商是否有远程模型源（决定 UI 是否展示同步状态 / 提供手动刷新入口）。
    var usesRemoteModelList: Bool { get }

    /// 上次成功同步远程模型的时间；静态型或从未同步成功时为 `nil`。
    var lastModelSyncDate: Date? { get }

    /// 发送非流式 LLM 完成请求。
    func complete(_ request: LLMRequest) async throws -> LLMResponse

    /// 是否已配置 API Key（本地供应商无需 Key，默认 `true`）。
    func hasApiKey() -> Bool

    /// 读取 API Key（未配置返回空串）。
    func getApiKey() -> String

    /// 为一次 API 请求可靠解析 API Key；供应商可覆盖读取、重试和错误分类。
    func resolveAPIKey() throws -> String

    /// 写入 API Key。
    func setApiKey(_ apiKey: String)

    /// 删除 API Key。
    func removeApiKey()
}

// MARK: - Default implementation（本地供应商无 Key 语义 + 静态模型列表语义）

public extension SuperLLMProvider {
    /// 默认静态实现：模型列表来自注册时的 `providerInfo.models`。
    ///
    /// 远程供应商应 override 本属性以提供动态模型池。
    var availableModels: [LLMModelInfo] { providerInfo.models }

    /// 默认实现为空操作（静态供应商无远程源）。
    func refreshModels() async throws {}

    /// 默认无远程模型源。
    var usesRemoteModelList: Bool { false }

    /// 默认无同步记录。
    var lastModelSyncDate: Date? { nil }

    func hasApiKey() -> Bool { true }
    func getApiKey() -> String { "" }
    func resolveAPIKey() throws -> String {
        let key = getApiKey().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw VendorAPIError.missingAPIKey(providerInfo.displayName)
        }
        return key
    }
    func setApiKey(_ apiKey: String) {}
    func removeApiKey() {}
}

/// `SuperLLMProvider` 的历史别名，保持下游测试兼容。
public typealias ManagedLLMProvider = SuperLLMProvider
