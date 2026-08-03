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

    /// Remove all registered sub-agent definitions during contribution rebuilds.
    func removeAllSubAgents()

    // MARK: - Execution (agent loop calls these)

    /// Find a tool by name
    func tool(named name: String) -> (any LumiAgentTool)?

    /// Resolve the user-facing description for a tool call.
    func displayDescription(for toolCall: LumiToolCall) -> String?

    /// Execute a tool call and return the result
    func execute(
        _ toolCall: LumiToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> LumiToolResult

    /// Query all persisted tool calls belonging to an agent turn.
    func toolCalls(for turnID: UUID) async -> [LumiToolCallRecord]

    /// Query the result of one tool invocation by its original tool-call ID.
    ///
    /// The ID is `LumiToolCall.id`, not the ID of a separate tool-log record.
    /// Implementations may return `nil` when the call is unknown, has not
    /// completed yet, or the backing result store is not available.
    func toolCallResult(for toolCallID: String) async -> LumiToolResult?
}

// MARK: - Default registration

public extension ToolManaging {
    /// Default implementation for tool managers that do not persist individual
    /// results yet. This keeps the new capability source-compatible while the
    /// concrete persistence layer is migrated incrementally.
    func toolCallResult(for toolCallID: String) async -> LumiToolResult? {
        nil
    }

    /// Backward-compatible execution entry point for callers outside the agent loop.
    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        await execute(toolCall, conversationID: conversationID, turnID: nil)
    }

    /// The plugin id used for tools registered without an explicit owner.
    static var builtInPluginID: String { "Built-in" }

    /// Add a single tool without attributing it to a plugin.
    /// Routes to `add(_:pluginID:)` with the `"Built-in"` group so the status-bar
    /// popover still surfaces it (e.g. for unmigrated third-party plugins).
    func add(_ tool: any LumiAgentTool) {
        add(tool, pluginID: Self.builtInPluginID)
    }

    /// Remove all registered tools. Used when rebuilding contributions (e.g. plugin enable/disable).
    func removeAll() {
        for tool in allAgentTools() {
            remove(id: tool.name)
        }
    }
}
