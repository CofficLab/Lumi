import Foundation

public typealias _AgentTool = LumiAgentTool
public typealias _SubAgentDefinition = LumiSubAgentDefinition

/// Tool management and execution capability.
///
/// Combines:
/// - Tool registration (called by plugins via `add()`)
/// - Tool execution (called by agent loop via `execute()`)
@MainActor
public protocol ToolManaging: AnyObject {
    // MARK: - Registration (plugins call these)

    /// All registered agent tools
    func allAgentTools() -> [any LumiAgentTool]

    /// Add a single tool
    func add(_ tool: any LumiAgentTool)

    /// Remove a tool by name
    func remove(id: String)

    /// All sub-agent definitions
    func allSubAgents() -> [LumiSubAgentDefinition]

    /// Add a sub-agent definition
    func addSubAgent(_ subAgent: LumiSubAgentDefinition)

    // MARK: - Execution (agent loop calls these)

    /// Find a tool by name
    func tool(named name: String) -> (any LumiAgentTool)?

    /// Execute a tool call and return the result
    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult
}
