import Foundation
import ProviderLLM

/// 可注册进 `LLMProviderManagerProviding` 的单个 LLM 供应商。
///
/// 对应旧版 `LumiLLMProvider`，但在 KernelCore 体系下基于 `LLMProviding`：
/// 供应商只需携带元数据（`providerInfo`）并实现 `complete(_:)`，协议细节
/// （OpenAI / Anthropic / Responses / 本地模型）由各实现翻译，管理器不感知。
///
/// 使用 `@MainActor` 约束与 `ToolManagerProviding` 等注册表型 Provider 一致，
/// 保证注册与选中状态在 UI 线程访问。
@MainActor
public protocol ManagedLLMProvider: LLMProviding {
    /// 供应商元数据：`providerInfo.id` 即注册表 key。
    var providerInfo: LLMProviderInfo { get }
}
