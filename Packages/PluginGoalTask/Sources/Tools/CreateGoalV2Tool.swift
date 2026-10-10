import KitAgentTool
import Foundation
import ProviderConversation

/// 创建 goal 及其任务列表的工具。
///
/// 必须经 `executeResult(context:)` 执行：goal 归属于当前 Agent 回合的会话
/// （刻意不读 UI 选中会话——用户可能在后台回合执行时切换对话）。
public struct CreateGoalV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "create_goal"
    public let name = toolName
    public init(conversations: (any ConversationManaging)? = nil) { _ = conversations }
    public func description(for language: LanguagePreference) -> String { "Create a goal with tasks for complex, multi-step work. Only one unfinished goal is allowed per conversation." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["title": ["type": "string", "description": "Short goal title", "minLength": 1], "description": ["type": "string", "description": "Detailed goal description"], "successCriteria": ["type": "string", "description": "Optional completion criteria"], "tasks": GoalTaskToolSupport.taskSchema(maxItems: GoalStateManager.maxTasksPerGoal)], "required": ["title", "tasks"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Create goal" }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(
            toolName: name,
            reason: "create_goal requires an Agent execution context"
        )
    }

    /// Context-aware entry point used by the real ToolManager. The context is
    /// created from the ToolJob's conversation ID, which is captured when the
    /// AgentLoop emits the tool call.
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(
            conversationID: context.conversationID,
            arguments: arguments
        ))
    }

    private func execute(
        conversationID: UUID,
        arguments: [String: ToolArgument]
    ) async throws -> String {
        guard let title = GoalTaskToolSupport.string(arguments, "title"), !title.isEmpty else { return "Error: title is required" }
        guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        let conversationId = conversationID.uuidString
        let tasks = GoalTaskToolSupport.taskInputs(arguments["tasks"]?.value)
        guard !tasks.isEmpty else { return "Error: no valid tasks found" }
        let existingGoals = await manager.fetchGoals(conversationId: conversationId)
        if let active = existingGoals.first(where: { ![Goal.GoalStatus.completed, .failed, .skipped].contains($0.status) }) {
            return "⚠️ Cannot create new goal: there is an unfinished goal.\n\n**Current goal:** \(active.title)\n**Goal ID:** `\(active.id)`\n**Status:** \(active.status.rawValue)\n\nComplete or skip it with `update_goal_status` (goal_id: `\(active.id)`) before creating another goal."
        }
        do {
            let result = try await manager.createGoal(conversationId: conversationId, title: title, description: GoalTaskToolSupport.string(arguments, "description"), successCriteria: GoalTaskToolSupport.string(arguments, "successCriteria"), tasks: tasks)
            GoalTaskToolSupport.changed(conversationId)
            let items = result.tasks.enumerated().map { "\($0.offset + 1). \($0.element.status == .inProgress ? "▶️" : "⏳") [\($0.element.id)] **\($0.element.title)**" }.joined(separator: "\n")
            return "✅ Created goal: **\(result.goal.title)**\n\n**Goal ID:** `\(result.goal.id)` — you MUST use this `goal_id` in `update_goal_status` / `add_tasks_to_goal` / `get_goal_progress`. Keep it for the whole conversation.\n\n**Tasks (\(result.tasks.count)):**\n\(items)\n\nNow start working on the first task (or first parallel group)."
        } catch { return "Error: failed to create goal: \(error.localizedDescription)" }
    }
}
