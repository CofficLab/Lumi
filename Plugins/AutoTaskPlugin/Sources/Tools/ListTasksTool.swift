import AgentToolKit
import Foundation
import SuperLogKit
import LumiCoreKit

/// 获取任务列表工具
///
/// 返回当前会话的所有任务，以结构化的列表形式展示 ID、标题、状态和详情。
/// 用于 Agent 需要查看完整任务列表以做决策的场景（如判断是否需要追加任务）。
public struct ListTasksTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    public let name = "list_tasks"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取当前会话的任务列表。返回所有任务的 ID、标题、状态和详情。用于查看完整任务信息以做决策，例如判断是否需要追加新任务。"
        case .english:
            return """
    Get the task list for the current conversation. Returns all tasks with their IDs, titles, \
    statuses, and details. Use this to review full task information for decision-making, \
    such as determining whether to append new tasks.
    """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "status": [
                    "type": "string",
                    "description": "Optional filter by status: 'pending', 'in_progress', 'completed', 'skipped'. Omit to return all tasks.",
                    "enum": ["pending", "in_progress", "completed", "skipped"],
                ],
            ],
            "required": [] as [String],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "列出任务" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationId.uuidString
        let manager = TaskStateManager.shared

        let tasks: [TaskItem]
        if let statusString = arguments["status"]?.value as? String,
           let status = TaskItem.TaskStatus(rawValue: statusString)
        {
            tasks = await manager.fetchTasks(conversationId: conversationId, status: status)
        } else {
            tasks = await manager.fetchTasks(conversationId: conversationId)
        }

        if tasks.isEmpty {
            return LumiPluginLocalization.string("No tasks found for this conversation. Use create_task to plan your work.", bundle: .module)
        }

        let statusLabels: [TaskItem.TaskStatus: String] = [
            .pending: "pending",
            .inProgress: "in_progress",
            .completed: "completed",
            .skipped: "skipped",
        ]

        var result = "📋 \(LumiPluginLocalization.string("Tasks (\(tasks.count) total)", bundle: .module))\n\n"
        for task in tasks {
            let statusLabel = statusLabels[task.status] ?? "unknown"
            result += "#\(task.order) `\(task.id)` [\(statusLabel)] **\(task.title)**"
            if let detail = task.detail {
                result += "\n   \(detail)"
            }
            result += "\n"
        }

        return result
    }
}
