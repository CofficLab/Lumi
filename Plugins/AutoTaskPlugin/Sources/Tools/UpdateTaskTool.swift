import Foundation
import LumiCoreKit
import SuperLogKit

/// 更新任务状态工具
///
/// 用于标记任务为进行中、已完成或跳过。
/// Agent 在完成一个任务后应调用此工具更新状态，以触发下一个任务的自动推进。
public struct UpdateTaskTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "✅"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "update_task",
        displayName: LumiPluginLocalization.string("Update Task", bundle: .module),
        description: LumiPluginLocalization.string(
            "Update the status of a task. Use this when you have started or completed a task. Mark a task as 'in_progress' when you begin working on it, and 'completed' when done. You can also 'skip' a task if it's not needed. After completing a task, check the remaining tasks and continue with the next one automatically.",
            bundle: .module
        )
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task_id": .object([
                    "type": .string("string"),
                    "description": .string("The ID of the task to update")
                ]),
                "status": .object([
                    "type": .string("string"),
                    "description": .string("New status: 'in_progress', 'completed', or 'skipped'"),
                    "enum": .array([.string("in_progress"), .string("completed"), .string("skipped")])
                ])
            ]),
            "required": .array([.string("task_id"), .string("status")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "更新任务状态" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationID.uuidString

        guard let taskId = arguments["task_id"]?.stringValue else {
            return LumiPluginLocalization.string("Error: task_id is required", bundle: .module)
        }

        guard let statusString = arguments["status"]?.stringValue,
              let status = TaskItem.TaskStatus(rawValue: statusString)
        else {
            return LumiPluginLocalization.string("Error: status must be one of: in_progress, completed, skipped", bundle: .module)
        }

        let manager = TaskStateManager.shared
        let success: Bool
        do {
            success = try await manager.updateTaskStatus(id: taskId, conversationId: conversationId, status: status)
        } catch {
            AutoTaskPlugin.logger.error("\(Self.t)Failed to update task \(taskId): \(error.localizedDescription)")
            return String(
                format: LumiPluginLocalization.string("Error: failed to save task status: %@", bundle: .module),
                error.localizedDescription
            )
        }

        guard success else {
            let notFoundLabel = LumiPluginLocalization.string("Error: task not found", bundle: .module)
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

        var result = "\(statusEmoji) \(LumiPluginLocalization.string("Task status updated", bundle: .module)): **\(status.rawValue)**"

        // 自动推进：完成任务后，将下一个 pending 任务标记为 inProgress
        if status == .completed || status == .skipped {
            let allTasks = await manager.fetchTasks(conversationId: conversationId)
            if let nextTask = allTasks.first(where: { $0.status == .pending }) {
                do {
                    let autoStarted = try await manager.updateTaskStatus(id: nextTask.id, conversationId: conversationId, status: .inProgress)
                    guard autoStarted else {
                        AutoTaskPlugin.logger.warning("\(Self.t)Pending task disappeared before auto-start: \(nextTask.id)")
                        return result
                    }
                } catch {
                    AutoTaskPlugin.logger.error("\(Self.t)Failed to auto-start next task \(nextTask.id): \(error.localizedDescription)")
                    let failedAutoStartLabel = String(
                        format: LumiPluginLocalization.string("Failed to auto-start next task: %@", bundle: .module),
                        error.localizedDescription
                    )
                    result += "\n\n⚠️ \(failedAutoStartLabel)"
                    return result
                }

                // 再次通知 UI 刷新（推进了下一个任务）
                NotificationCenter.default.post(
                    name: .autoTaskDidChange,
                    object: nil,
                    userInfo: ["conversationId": conversationId]
                )

                let autoStartedLabel = LumiPluginLocalization.string("Next task auto-started", bundle: .module)
                result += "\n\n📌 **\(autoStartedLabel): \(nextTask.title) (id: \(nextTask.id))**"
                result += "\n\(LumiPluginLocalization.string("Continue working on this task now.", bundle: .module))"

                if Self.verbose {
                    AutoTaskPlugin.logger.info("\(Self.t)Auto-started next task: \(nextTask.title)")
                }
            }
        }

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)Task \(taskId) → \(status.rawValue)")
        }

        return result
    }
}
