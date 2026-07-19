import Foundation

/// Agent 工具信息接口
public protocol AgentToolInfo: Sendable {
    var name: String { get }
    var description: String { get }
}

// MARK: - Agent Tool Item

/// Agent 工具项
///
/// 用于单个工具注册的包装结构。
public struct AgentToolItem: Identifiable, Sendable {
    public let id: String
    public let tool: any AgentToolInfo

    public init(tool: any AgentToolInfo) {
        self.id = tool.name
        self.tool = tool
    }
}
