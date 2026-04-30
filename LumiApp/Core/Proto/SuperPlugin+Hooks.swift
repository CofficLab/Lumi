import Foundation

// MARK: - Agent Tools Default Implementation

extension SuperPlugin {
    @MainActor func agentTools() -> [AgentTool] { [] }

    @MainActor func agentToolFactories() -> [AnyAgentToolFactory] { [] }

    @MainActor func sendMiddlewares() -> [AnySendMiddleware] { [] }

    /// 插件提供的 LLM 供应商类型
    ///
    /// 如果插件是一个 LLM 供应商插件，返回对应的 `SuperLLMProvider.Type`。
    /// `PluginVM` 会在插件注册阶段自动收集并注册到 `LLMProviderRegistry`。
    ///
    /// 默认返回 `nil`，表示该插件不提供 LLM 供应商。
    ///
    /// ## 使用示例
    ///
    /// ```swift
    /// actor OpenRouterPlugin: SuperPlugin {
    ///     func llmProviderType() -> (any SuperLLMProvider.Type)? {
    ///         OpenRouterProvider.self
    ///     }
    /// }
    /// ```
    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? { nil }
}
