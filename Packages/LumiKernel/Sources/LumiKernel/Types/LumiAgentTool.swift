@_exported import LumiCoreAgentTool

// MARK: - Lumi Agent Tool type aliases

/// Agent 工具协议
public typealias LumiAgentTool = LumiCoreAgentTool.LumiAgentTool

/// Agent 工具信息
public typealias LumiAgentToolInfo = LumiCoreAgentTool.LumiAgentToolInfo

/// Agent 工具服务协议
public typealias LumiToolServicing = LumiCoreAgentTool.LumiToolServicing

/// 命令风险等级
public typealias LumiCommandRiskLevel = LumiCoreAgentTool.LumiCommandRiskLevel

/// Agent 工具项
public struct AgentToolItem: Identifiable, Sendable {
    public let id: String
    public let tool: any LumiAgentTool

    public init(tool: any LumiAgentTool) {
        self.id = tool.name
        self.tool = tool
    }
}
