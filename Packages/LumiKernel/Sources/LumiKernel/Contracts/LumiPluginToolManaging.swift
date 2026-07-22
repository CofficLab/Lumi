import Foundation



/// Agent Tool 贡献协议 (LumiCoreChat 消费版本)
///
/// 把"插件 → 工具 / 子 Agent"的收集能力抽象出来，让 `LumiCore` 能直接消费
/// `PluginService` 提供的工具和子 Agent 定义，而不需要在 App 层手工拼装。
///
/// 实现者通常是 App 层的 `PluginService`。`AgentToolComponent.buildToolSet`
/// 会调用这两个方法完成所有工具编排。
@MainActor
public protocol LumiPluginToolManaging: AnyObject {
    /// 收集所有启用插件的 `LumiAgentTool`
    func agentTools(lumiCore: any LumiCoreProviding) -> [any LumiAgentTool]

    /// 收集所有启用插件的 `LumiSubAgentDefinition`
    func subAgents(lumiCore: any LumiCoreProviding) -> [LumiSubAgentDefinition]

    /// 返回最近一次 `agentTools(lumiCore:)` 收集过程中累积的插件失败列表。
    ///
    /// 聚合层（`LumiPluginRegistry`）在收集工具时会逐插件捕获异常并包装成
    /// `LumiPluginContributionFailure`。`AgentToolComponent` 在 bootstrap 结束后
    /// 通过本方法读取这份失败快照，供 UI 展示。
    ///
    /// 默认返回空数组（无聚合能力的实现者不受影响）。
    func lastAgentToolFailures() -> [LumiPluginContributionFailure]
}

public extension LumiPluginToolManaging {
    /// 默认实现：无聚合能力的 provider 不会产生失败。
    func lastAgentToolFailures() -> [LumiPluginContributionFailure] { [] }
}
