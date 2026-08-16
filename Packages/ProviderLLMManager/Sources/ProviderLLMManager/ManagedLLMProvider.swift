import Foundation
import ProviderLLM

/// 可注册进 `LLMProviderManagerProviding` 的单个 LLM 供应商。
///
/// 对应旧版 `LumiLLMProvider`，但在 KernelCore 体系下基于 `LLMProviding`：
/// 供应商只需携带元数据（`providerInfo`）并实现 `complete(_:)`，协议细节
/// （OpenAI / Anthropic / Responses / 本地模型）由各实现翻译，管理器不感知。
///
/// API Key 管理方法与旧版 `LumiLLMProvider` 的 `hasApiKey` / `getApiKey` /
/// `setApiKey` / `removeApiKey` 一一对应，设置页等 UI 通过协议统一操作，
/// 不感知具体实现（本地供应商默认无需 Key）。
///
/// 使用 `@MainActor` 约束与 `ToolManagerProviding` 等注册表型 Provider 一致，
/// 保证注册与选中状态在 UI 线程访问。
@MainActor
public protocol ManagedLLMProvider: LLMProviding {
    /// 供应商元数据：`providerInfo.id` 即注册表 key。
    var providerInfo: LLMProviderInfo { get }

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

public extension ManagedLLMProvider {
    func hasApiKey() -> Bool { true }
    func getApiKey() -> String { "" }
    func setApiKey(_ apiKey: String) {}
    func removeApiKey() {}
}
