import Foundation

/// LLM Provider 注册服务
///
/// 由 LLM Provider 插件实现,负责把 LLMProvider 实例注册到内核。
@MainActor
public protocol LLMProviderManaging: AnyObject {
    /// 所有已注册的 LLM Provider
    func allLLMProviders() -> [any LumiLLMProvider]

    /// 注册单个 LLM Provider
    ///
    /// - Throws: `LumiKernelError.llmProviderRegistrationFailed` 当 provider 的
    ///   `info.id` 为空时。
    func registerLLMProvider(_ provider: any LumiLLMProvider) throws

    /// 批量注册 LLM Provider
    ///
    /// 按数组顺序逐个调用 `registerLLMProvider(_:)`,等价于:
    ///
    ///     for provider in providers {
    ///         try registerLLMProvider(provider)
    ///     }
    ///
    /// - Parameter providers: 待注册的 provider 列表
    /// - Throws: 转发自单个 `registerLLMProvider(_:)` 的错误。批量过程中遇到失败
    ///   会立即停止,已注册的 provider 保留。
    func registerLLMProviders(_ providers: [any LumiLLMProvider]) throws

    /// 注销单个 LLM Provider
    func unregisterLLMProvider(id: String)

    /// 按 ID 查询
    func llmProvider(id: String) -> (any LumiLLMProvider)?

    /// 当前选中的 Provider ID
    var selectedProviderID: String? { get }

    /// 设置当前选中的 Provider
    func selectProvider(id: String)

    /// 获取指定 provider 下的模型列表
    func models(for providerID: String) -> [String]

    /// 当前选中的模型
    var selectedModel: String? { get }

    /// 选择 Provider 和 Model
    func selectModel(providerID: String, model: String)

    /// 发送一条请求到「第一个可用」的 LLM provider
    ///
    /// - Parameter request: LLM 请求(消息历史 + 模型名 + 可选工具列表)
    /// - Returns: 完整 assistant 消息
    /// - Throws: `LumiKernelError.llmProviderUnavailable` 当内核未注册任何 provider 时
    func sendToFirstProvider(_ request: LumiLLMRequest) async throws -> LumiChatMessage

    /// 发送一条请求到「当前选中」的 LLM provider 和 model
    ///
    /// - Parameter request: LLM 请求(消息历史 + 模型名 + 可选工具列表)
    /// - Returns: 完整 assistant 消息
    /// - Throws: `LumiKernelError.llmProviderUnavailable` 当内核未注册任何 provider 时
    /// - Throws: `LumiKernelError.invalidProviderOrModel` 当没有选中的 provider 或 model 时
    func sendToSelectedProvider(_ request: LumiLLMRequest) async throws -> LumiChatMessage
}

public extension LLMProviderManaging {
    /// 默认实现:按数组顺序逐个调用 `registerLLMProvider(_:)`。
    /// 已有实现可以重写此方法以获得更好的性能(例如单次日志输出、原子更新等)。
    func registerLLMProviders(_ providers: [any LumiLLMProvider]) throws {
        for provider in providers {
            try registerLLMProvider(provider)
        }
    }
}
