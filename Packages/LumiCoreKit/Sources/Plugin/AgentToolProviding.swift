import Foundation

/// Agent Tool 贡献协议
///
/// 把"插件 → 工具 / 子 Agent"的收集能力抽象出来，让 `LumiCore` 能直接消费
/// `PluginService` 提供的工具和子 Agent 定义，而不需要在 App 层手工拼装。
///
/// 实现者通常是 App 层的 `PluginService`。`LumiCore.bootstrapToolContributions`
/// 会调用这两个方法完成所有工具编排。
@MainActor
public protocol AgentToolProviding: AnyObject {
    /// 收集所有启用插件的 `LumiAgentTool`
    func agentTools(context: LumiPluginContext) -> [any LumiAgentTool]

    /// 收集所有启用插件的 `LumiSubAgentDefinition`
    func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition]
}
