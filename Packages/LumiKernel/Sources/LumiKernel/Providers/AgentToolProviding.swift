import Foundation
import LumiCoreAgentTool
import LumiCoreMessage
import LumiCoreSubAgent

// Type aliases to avoid ambiguity with LumiCoreAgentTool.LumiAgentTool / LumiSubAgentDefinition
public typealias _AgentTool = LumiCoreAgentTool.LumiAgentTool
public typealias _SubAgentDefinition = LumiCoreSubAgent.LumiSubAgentDefinition

/// Agent 工具注册服务
///
/// 由 Agent Tool 插件实现,负责把 AgentTool / SubAgent 实例注册到内核。
@MainActor
public protocol AgentToolProviding: AnyObject {
    /// 收集所有已启用的 Agent Tool
    func allAgentTools() -> [any LumiAgentTool]

    /// 注册单个 Agent Tool
    func add(_ tool: any LumiAgentTool)

    /// 注销单个 Agent Tool
    func remove(id: String)

    /// 收集所有 SubAgent 定义
    func allSubAgents() -> [LumiSubAgentDefinition]

    /// 注册 SubAgent 定义
    func addSubAgent(_ subAgent: LumiSubAgentDefinition)
}
