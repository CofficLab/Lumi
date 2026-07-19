import Foundation

/// Agent 工具能力协议
///
/// 定义 LumiCore 需要的 Agent 工具功能。
/// 由具体实现（如插件）提供，不在 LumiKernel 中实现。
@MainActor
public protocol AgentToolProviding: AnyObject {
    /// 所有已注册的 Agent 工具
    var allAgentTools: [any LumiAgentTool] { get }

    /// 注册单个 Agent 工具
    func register(_ tool: any LumiAgentTool)

    /// 注销 Agent 工具
    func unregister(id: String)

    /// 收集工具
    func collectTools() async throws -> [any LumiAgentTool]

    /// 执行工具
    func executeTool(name: String, arguments: String, context: LumiToolExecutionContext) async throws -> String
}
