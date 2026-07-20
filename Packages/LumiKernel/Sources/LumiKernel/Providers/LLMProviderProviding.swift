import Foundation
import LumiCoreLLMProvider
import LumiCoreMessage

/// LLM Provider 注册服务
///
/// 由 LLM Provider 插件实现,负责把 LLMProvider 实例注册到内核。
@MainActor
public protocol LLMProviderProviding: AnyObject {
    /// 收集所有已启用的 LLM Provider
    func allLLMProviders() -> [any LumiLLMProvider]

    /// 注册单个 LLM Provider
    func registerLLMProvider(_ provider: any LumiLLMProvider)

    /// 注销单个 LLM Provider
    func unregisterLLMProvider(id: String)

    /// 按 ID 查询
    func llmProvider(id: String) -> (any LumiLLMProvider)?
}
