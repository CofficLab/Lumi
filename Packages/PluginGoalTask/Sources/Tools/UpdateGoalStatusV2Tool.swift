import KitAgentTool
import Foundation
import ProviderConversation

/// 更新 goal 状态（含 blocked / failed 原因）的工具。
///
/// `goal_id` 可省略：会话内恰好一个活跃 goal 时自动解析。
public struct UpdateGoalStatusV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "update_goal_status"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Update a goal's status, including blocked or failed reasons." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["goal_id": ["type": "string", "description": "Goal ID from create_goal's **Goal ID** line (or its exact title). Optional when the conversation has exactly one active goal.", "minLength": 1], "status": ["type": "string", "enum": GoalTaskToolSupport.goalStatuses], "blocked_reason": ["type": "string"], "failure_reason": ["type": "string"], "suggested_actions": ["type": "array", "items": ["type": "string"]]], "required": ["status"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Update goal status" }

    public func executeResult(context: ToolExecutionContext, arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(conversationID: context.conversationID, arguments: arguments))
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(conversationID: nil, arguments: arguments)
    }

    private func execute(conversationID: UUID?, arguments: [String: ToolArgument]) async throws -> String {
        guard let value = GoalTaskToolSupport.string(arguments, "status"), let status = Goal.GoalStatus(rawValue: value) else { return "Error: invalid status" }
        guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        let goalId: String
        switch await GoalTaskToolSupport.resolveGoalId(raw: GoalTaskToolSupport.string(arguments, "goal_id"), conversationId: conversationID?.uuidString, manager: manager) {
        case .success(let id): goalId = id
        case .failure(let error): return error.message
        }
        do { let goal = try await manager.updateGoalStatus(id: goalId, status: status, blockedReason: GoalTaskToolSupport.string(arguments, "blocked_reason"), failureReason: GoalTaskToolSupport.string(arguments, "failure_reason")); GoalTaskToolSupport.changed(goal.conversationId); return "✅ Goal **\(goal.title)** (Goal ID: `\(goal.id)`) updated to **\(status.rawValue)**" } catch { return "Error: failed to update goal: \(error.localizedDescription)" }
    }
}
