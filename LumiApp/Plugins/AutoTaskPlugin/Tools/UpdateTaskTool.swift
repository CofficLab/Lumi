import Foundation
import AgentToolKit

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
            return "更新任务状态。开始处理任务时将其标记为 'in_progress'，完成后标记为 'completed'。如果任务不再需要，也可以标记为 'skipped'。完成一个任务后，应检查剩余任务并自动继续下一个。"
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
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationId.uuidString

        guard let taskId = arguments["task_id"]?.value as? String else {
            return String(localized: "Error: task_id is required", table: "AutoTask")
        }

        guard let statusString = arguments["status"]?.value as? String,
              let status = TaskItem.TaskStatus(rawValue: statusString)
        else {
            return String(localized: "Error: status must be one of: in_progress, completed, skipped", table: "AutoTask")
        }

        let manager = TaskStateManager.shared
        let success = await manager.updateTaskStatus(id: taskId, conversationId: conversationId, status: status)

        guard success else {
            let notFoundLabel = String(localized: "Error: task not found", table: "AutoTask")
            return "\(notFoundLabel) (id: \(taskId))"
        }

        // 通知 UI 刷新
        NotificationCenter.default.post(
            name: .autoTaskDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )

        let statusEmoji: String
        switch status {
        case .inProgress: statusEmoji = "🔄"
        case .completed: statusEmoji = "✅"
        case .skipped: statusEmoji = "⏭️"
        case .pending: statusEmoji = "📋"
        }

        var result = "\(statusEmoji) \(String(localized: "Task status updated", table: "AutoTask")): **\(status.rawValue)**"

        // 自动推进：完成任务后，将下一个 pending 任务标记为 inProgress
        if status == .completed || status == .skipped {
            let allTasks = await manager.fetchTasks(conversationId: conversationId)
            if let nextTask = allTasks.first(where: { $0.status == .pending }) {
                _ = await manager.updateTaskStatus(id: nextTask.id, conversationId: conversationId, status: .inProgress)

                // 再次通知 UI 刷新（推进了下一个任务）
                NotificationCenter.default.post(
                    name: .autoTaskDidChange,
                    object: nil,
                    userInfo: ["conversationId": conversationId]
                )

                let autoStartedLabel = String(localized: "Next task auto-started", table: "AutoTask")
                result += "\n\n📌 **\(autoStartedLabel): \(nextTask.title) (id: \(nextTask.id))**"
                result += "\n\(String(localized: "Continue working on this task now.", table: "AutoTask"))"

                if Self.verbose {
                    if AutoTaskPlugin.verbose {
                                            AutoTaskPlugin.logger.info("\(Self.t)Auto-started next task: \(nextTask.title)")
                    }
                }
            }
        }

        if Self.verbose {
            if AutoTaskPlugin.verbose {
                            AutoTaskPlugin.logger.info("\(Self.t)Task \(taskId) → \(status.rawValue)")
            }
        }

        return result
    }
}
