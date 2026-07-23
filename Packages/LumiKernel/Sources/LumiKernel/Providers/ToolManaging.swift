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

    /// Add a single tool, attributing it to a plugin (used to group tools in the UI).
    func add(_ tool: any LumiAgentTool, pluginID: String)

    /// Remove a tool by name
    func remove(id: String)

    /// Tools grouped by the plugin that registered them, in registration order.
    /// Each entry is `(pluginID, tools)`; the fallback `"Built-in"` bucket
    /// collects tools registered without a plugin id.
    func agentToolsGroupedByPlugin() -> [(pluginID: String, tools: [any LumiAgentTool])]

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

// MARK: - Default registration

public extension ToolManaging {
    /// The plugin id used for tools registered without an explicit owner.
    static var builtInPluginID: String { "Built-in" }

    /// Add a single tool without attributing it to a plugin.
    /// Routes to `add(_:pluginID:)` with the `"Built-in"` group so the status-bar
    /// popover still surfaces it (e.g. for unmigrated third-party plugins).
    func add(_ tool: any LumiAgentTool) {
        add(tool, pluginID: Self.builtInPluginID)
    }
}
