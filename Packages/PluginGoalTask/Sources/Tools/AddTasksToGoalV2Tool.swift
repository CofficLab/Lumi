import KitAgentTool
import Foundation
import ProviderConversation

/// 向已有 goal 追加任务的工具（多发现型工作）。
///
/// `goal_id` 可省略：会话内恰好一个活跃 goal 时自动解析。
public struct AddTasksToGoalV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "add_tasks_to_goal"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Add new tasks to an existing goal when more work is discovered." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["goal_id": ["type": "string", "description": "Goal ID from create_goal's **Goal ID** line (or its exact title). Optional when the conversation has exactly one active goal.", "minLength": 1], "tasks": GoalTaskToolSupport.taskSchema()], "required": ["tasks"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Add tasks to goal" }

    public func executeResult(context: ToolExecutionContext, arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(conversationID: context.conversationID, arguments: arguments))
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(conversationID: nil, arguments: arguments)
    }

    private func execute(conversationID: UUID?, arguments: [String: ToolArgument]) async throws -> String {
        guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        let inputs = GoalTaskToolSupport.taskInputs(arguments["tasks"]?.value); guard !inputs.isEmpty else { return "Error: no valid tasks found" }
        let goalId: String
        switch await GoalTaskToolSupport.resolveGoalId(raw: GoalTaskToolSupport.string(arguments, "goal_id"), conversationId: conversationID?.uuidString, manager: manager) {
        case .success(let id): goalId = id
        case .failure(let error): return error.message
        }
        do {
            let tasks = try await manager.addTasksToGoal(goalId: goalId, tasks: inputs)
            if let goal = await manager.fetchGoal(id: goalId) { await manager.resetContinuationCount(conversationId: goal.conversationId); GoalTaskToolSupport.changed(goal.conversationId); return "✅ Added \(tasks.count) tasks to goal\n\n**Goal ID:** `\(goal.id)`\n\n" + tasks.enumerated().map { "\($0.offset + 1). [\($0.element.id)] **\($0.element.title)**" }.joined(separator: "\n") }
            return "✅ Added \(tasks.count) tasks to goal\n\n" + tasks.enumerated().map { "\($0.offset + 1). [\($0.element.id)] **\($0.element.title)**" }.joined(separator: "\n")
        } catch { return "Error: failed to add tasks: \(error.localizedDescription)" }
    }
}
