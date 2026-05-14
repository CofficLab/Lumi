import Foundation
import MagicKit

/// 更新任务状态工具
///
/// 用于标记任务为进行中、已完成或跳过。
/// Agent 在完成一个任务后应调用此工具更新状态，以触发下一个任务的自动推进。
struct UpdateTaskTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "✅"
    nonisolated static let verbose: Bool = false

    let name = "update_task"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "Update the status of a task. Use this when you have started or completed a task. \\nMark a task as 'in_progress' when you begin working on it, and 'completed' when done. \\nYou can also 'skip' a task if it's not needed. \\nAfter completing a task, check the remaining tasks and continue with the next one automatically."
        case .english:
            return     """
    Update the status of a task. Use this when you have started or completed a task. \
    Mark a task as 'in_progress' when you begin working on it, and 'completed' when done. \
    You can also 'skip' a task if it's not needed. \
    After completing a task, check the remaining tasks and continue with the next one automatically.
    """
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "task_id": [
                    "type": "string",
                    "description": "The ID of the task to update",
                ],
                "status": [
                    "type": "string",
                    "description": "New status: 'in_progress', 'completed', or 'skipped'",
                    "enum": ["in_progress", "completed", "skipped"],
                ],
            ],
            "required": ["task_id", "status"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let taskId = arguments["task_id"]?.value as? String else {
            return "Error: task_id is required"
        }

        guard let statusString = arguments["status"]?.value as? String,
              let status = TaskItem.TaskStatus(rawValue: statusString)
        else {
            return "Error: status must be one of: in_progress, completed, skipped"
        }

        let manager = TaskStateManager.shared
        let success = await manager.updateTaskStatus(id: taskId, status: status)

        guard success else {
            return "Error: task not found (id: \(taskId))"
        }

        // 通知 UI 刷新
        if let task = await manager.fetchTask(id: taskId) {
            NotificationCenter.default.post(
                name: .autoTaskDidChange,
                object: nil,
                userInfo: ["conversationId": task.conversationId]
            )
        }

        let statusEmoji: String
        switch status {
        case .inProgress: statusEmoji = "🔄"
        case .completed: statusEmoji = "✅"
        case .skipped: statusEmoji = "⏭️"
        case .pending: statusEmoji = "📋"
        }

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)Task \(taskId) → \(status.rawValue)")
        }

        return "\(statusEmoji) Task status updated to **\(status.rawValue)**."
    }
}
