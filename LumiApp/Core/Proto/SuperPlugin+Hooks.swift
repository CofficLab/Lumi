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

    /// 插件提供的消息渲染器列表
    ///
    /// 如果插件提供自定义消息渲染器，返回 `SuperMessageRenderer` 实例数组。
    /// `PluginVM` 会在插件注册阶段自动收集并注册到 `MessageRendererVM`。
    ///
    /// 默认返回空数组，表示该插件不提供消息渲染器。
    ///
    /// ## 使用示例
    ///
    /// ```swift
    /// actor MyPlugin: SuperPlugin {
    ///     func messageRenderers() -> [any SuperMessageRenderer] {
    ///         [MyCustomRenderer(), AnotherRenderer()]
    ///     }
    /// }
    /// ```
    @MainActor func messageRenderers() -> [any SuperMessageRenderer] { [] }
}
