import KitAgentTool
import Foundation
import ProviderConversation

/// 更新单个任务状态并重算所属 goal 的工具。
///
/// 经 `executeResult(context:)` 执行时校验任务归属当前 Agent 回合的会话，
/// 拒绝跨会话改写（#190）。
public struct UpdateTaskStatusV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "update_task_status"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Update one task's status and recalculate its parent goal." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["task_id": ["type": "string", "minLength": 1], "status": ["type": "string", "enum": GoalTaskToolSupport.taskStatuses], "result": ["type": "string"], "error_message": ["type": "string"]], "required": ["task_id", "status"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Update task status" }

    public func executeResult(context: ToolExecutionContext, arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(conversationID: context.conversationID, arguments: arguments))
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(conversationID: nil, arguments: arguments)
    }

    private func execute(conversationID: UUID?, arguments: [String: ToolArgument]) async throws -> String {
        guard let taskId = GoalTaskToolSupport.string(arguments, "task_id"), let value = GoalTaskToolSupport.string(arguments, "status"), let status = GoalTask.TaskStatus(rawValue: value) else { throw GoalTaskToolSupport.GoalTaskToolError(message: "invalid status") }; guard let manager = GoalTaskToolSupport.manager() else { throw GoalTaskToolSupport.GoalTaskToolError(message: "goal task manager is not initialized") }
        // 带会话上下文时任务必须属于本会话，禁止跨会话改写任务/Goal/续跑预算（#190）；无上下文旧入口保持全局查找。
        if let conversationID {
            guard let task = await manager.fetchGoalTask(id: taskId),
                  let goal = await manager.fetchGoal(id: task.goalId),
                  goal.conversationId == conversationID.uuidString else {
                throw GoalTaskToolSupport.GoalTaskToolError(message: "task not found: `\(taskId)`")
            }
        }
        do { let result = try await manager.updateGoalTaskStatus(id: taskId, status: status, result: GoalTaskToolSupport.string(arguments, "result"), errorMessage: GoalTaskToolSupport.string(arguments, "error_message")); await manager.resetContinuationCount(conversationId: result.goal.conversationId); GoalTaskToolSupport.changed(result.goal.conversationId); return "✅ Task **\(result.task.title)** updated to **\(status.rawValue)**\n\nGoal **\(result.goal.title)** (Goal ID: `\(result.goal.id)`) status: **\(result.goal.status.rawValue)**" } catch { throw GoalTaskToolSupport.GoalTaskToolError(message: "failed to update task: \(error.localizedDescription)") }
    }
}
