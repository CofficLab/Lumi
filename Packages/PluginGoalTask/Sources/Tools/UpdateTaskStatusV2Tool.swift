import KitAgentTool
import Foundation
import ProviderConversation

/// 更新单个任务状态并重算所属 goal 的工具。
public struct UpdateTaskStatusV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "update_task_status"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Update one task's status and recalculate its parent goal." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["task_id": ["type": "string", "minLength": 1], "status": ["type": "string", "enum": GoalTaskToolSupport.taskStatuses], "result": ["type": "string"], "error_message": ["type": "string"]], "required": ["task_id", "status"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Update task status" }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let taskId = GoalTaskToolSupport.string(arguments, "task_id"), let value = GoalTaskToolSupport.string(arguments, "status"), let status = GoalTask.TaskStatus(rawValue: value) else { return "Error: invalid status" }; guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        do { let result = try await manager.updateGoalTaskStatus(id: taskId, status: status, result: GoalTaskToolSupport.string(arguments, "result"), errorMessage: GoalTaskToolSupport.string(arguments, "error_message")); await manager.resetContinuationCount(conversationId: result.goal.conversationId); GoalTaskToolSupport.changed(result.goal.conversationId); return "✅ Task **\(result.task.title)** updated to **\(status.rawValue)**\n\nGoal **\(result.goal.title)** (Goal ID: `\(result.goal.id)`) status: **\(result.goal.status.rawValue)**" } catch { return "Error: failed to update task: \(error.localizedDescription)" }
    }
}
