import Foundation

// MARK: - Agent Tools Hooks

extension SuperPlugin {
    /// 提供 Agent 工具列表。
    ///
    /// 插件可以通过实现此方法，向系统注册一组 `AgentTool`，
    /// 这些工具会与内核内置工具、MCP 工具一起组成完整的工具集。
    @MainActor func agentTools() -> [AgentTool]

    /// 提供 Agent 工具工厂列表（带依赖注入）。
    ///
    /// 当工具需要依赖 `ToolService` / `LLMService` 等上下文时，建议使用工厂方式构造。
    @MainActor func agentToolFactories() -> [AnyAgentToolFactory]
}

// MARK: - Worker Hooks

extension SuperPlugin {
    /// 提供 Worker 描述符列表。
    ///
    /// 用于向系统注册可用的 worker 类型（由插件决定有哪些 worker）。
    @MainActor func workerAgentDescriptors() -> [WorkerAgentDescriptor]

    /// 提供工具展示描述符列表。
    ///
    /// 用于统一工具名称、emoji 与展示分类，减少内核和 UI 的硬编码映射。
    @MainActor func toolPresentationDescriptors() -> [ToolPresentationDescriptor]
}

// MARK: - MCP Server Hooks

extension SuperPlugin {
    /// 提供 MCP 服务器配置列表。
    ///
    /// 插件可通过返回配置模板来注册 MCP 工具来源。
    @MainActor func mcpServerConfigs() -> [MCPServerConfig]
}

// MARK: - Agent Tools & Worker Default Implementation

extension SuperPlugin {
    @MainActor func agentTools() -> [AgentTool] { [] }

    @MainActor func agentToolFactories() -> [AnyAgentToolFactory] { [] }

    @MainActor func workerAgentDescriptors() -> [WorkerAgentDescriptor] { [] }

    @MainActor func toolPresentationDescriptors() -> [ToolPresentationDescriptor] { [] }

    @MainActor func mcpServerConfigs() -> [MCPServerConfig] { [] }
}
