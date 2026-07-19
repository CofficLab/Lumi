import Foundation

/// Agent 工具信息接口
///
/// 简单协议，仅提供工具的基本信息。
/// 完整的工具实现应使用 `LumiAgentTool` 协议。
public protocol AgentToolInfo: Sendable {
    var name: String { get }
    var description: String { get }
}

// MARK: - LumiAgentTool + AgentToolInfo

extension LumiAgentTool {
    public var description: String {
        toolDescription
    }
}

// MARK: - Agent Tool Item

/// Agent 工具项
///
/// 用于单个工具注册的包装结构。
public struct AgentToolItem: Identifiable, Sendable {
    public let id: String
    public let tool: any LumiAgentTool

    public init(tool: any LumiAgentTool) {
        self.id = tool.name
        self.tool = tool
    }
}

// MARK: - LumiAgentToolInfo

/// Agent 工具信息。
public struct LumiAgentToolInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String

    public init(id: String, displayName: String, description: String) {
        self.id = id
        self.displayName = displayName
        self.description = description
    }
}

// MARK: - LumiAgentTool Protocol

/// Agent 工具协议。
///
/// 实现此协议以提供 Agent 可调用的工具。
public protocol LumiAgentTool: Sendable {
    /// 工具的静态信息。
    static var info: LumiAgentToolInfo { get }

    /// 工具的特征标签。
    var tags: Set<LumiToolTag> { get }

    /// 工具名称。
    var name: String { get }

    /// 工具描述。
    var toolDescription: String { get }

    /// 输入参数的 JSON Schema。
    var inputSchema: LumiJSONValue { get }

    /// 执行工具。
    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String

    /// 评估风险等级。
    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel

    /// 显示描述。
    func displayDescription(arguments: [String: LumiJSONValue]) -> String
}

// MARK: - Default Implementations

public extension LumiAgentTool {
    var name: String {
        Self.info.id
    }

    var toolDescription: String {
        Self.info.description
    }

    var tags: Set<LumiToolTag> { [] }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        Self.info.displayName
    }
}
