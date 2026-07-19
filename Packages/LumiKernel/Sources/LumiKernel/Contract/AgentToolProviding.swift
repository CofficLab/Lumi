import Foundation

// MARK: - Agent Tool Info

/// Agent 工具信息接口
public protocol AgentToolInfo: Sendable {
    var name: String { get }
    var description: String { get }
}

// MARK: - Agent Tool Capability Protocol

/// Agent 工具能力协议
///
/// 定义 LumiCore 需要的 Agent 工具功能。
@MainActor
public protocol AgentToolProviding: AnyObject {
    /// 收集工具
    func collectTools() async throws -> [any AgentToolInfo]

    /// 执行工具
    func executeTool(name: String, arguments: String) async throws -> String
}