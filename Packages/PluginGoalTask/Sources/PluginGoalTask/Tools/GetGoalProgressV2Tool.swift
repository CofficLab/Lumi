import KitAgentTool
import Foundation
import ProviderConversation

/// 查询 goal 进度、任务与状态的工具。
///
/// `goal_id` 可省略：会话内恰好一个活跃 goal 时自动解析。
public struct GetGoalProgressV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "get_goal_progress"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Query a goal's progress, tasks, and statuses. goal_id may be omitted to resolve the conversation's active goal automatically." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["goal_id": ["type": "string", "description": "Goal ID from create_goal's **Goal ID** line (or its exact title). Optional when the conversation has exactly one active goal.", "minLength": 1]], "required": []] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Get goal progress" }

    public func executeResult(context: ToolExecutionContext, arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(conversationID: context.conversationID, arguments: arguments))
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(conversationID: nil, arguments: arguments)
    }

    private func execute(conversationID: UUID?, arguments: [String: ToolArgument]) async throws -> String {
        guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        let goalId: String
        switch await GoalTaskToolSupport.resolveGoalId(raw: GoalTaskToolSupport.string(arguments, "goal_id"), conversationId: conversationID?.uuidString, manager: manager) {
        case .success(let id): goalId = id
        case .failure(let error): return error.message
        }
        guard let goal = await manager.fetchGoal(id: goalId) else { return "Error: goal not found" }
        let tasks = await manager.fetchTasks(goalId: goalId); let completed = tasks.filter { $0.status == .completed }.count; let skipped = tasks.filter { $0.status == .skipped }.count; let failed = tasks.filter { $0.status == .failed }.count; let active = tasks.filter { $0.status == .inProgress }.count; let pending = tasks.filter { $0.status == .pending }.count
        let progress = tasks.isEmpty ? 0 : Int(Double(completed + skipped) / Double(tasks.count) * 100)
        let rows = tasks.enumerated().map { index, task in "\(index + 1). \(icon(task.status)) \(task.title) [\(task.status.rawValue)]" }.joined(separator: "\n")
        return "## 🎯 \(goal.title)\n**Goal ID:** `\(goal.id)`\n**Status:** \(goal.status.rawValue)\n\n**Progress:** \(completed + skipped)/\(tasks.count) (\(progress)%)\n- Completed: \(completed)\n- Skipped: \(skipped)\n- Failed: \(failed)\n- In Progress: \(active)\n- Pending: \(pending)\n\n**Tasks:**\n\(rows)"
    }

    private func icon(_ status: GoalTask.TaskStatus) -> String { switch status { case .completed: "✅"; case .inProgress: "▶️"; case .failed: "❌"; case .skipped: "⏭️"; case .pending: "⏳" } }
}
