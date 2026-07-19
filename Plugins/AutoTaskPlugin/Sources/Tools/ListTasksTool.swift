import Foundation
import LumiKernel
import SuperLogKit

/// 获取任务列表工具
///
/// 返回当前会话的所有任务，以结构化的列表形式展示 ID、标题、状态和详情。
/// 用于 Agent 需要查看完整任务列表以做决策的场景（如判断是否需要追加任务）。
public struct ListTasksTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    /// 由插件注入的状态管理器。
    ///
    /// 由 `AutoTaskPlugin` 在 `agentTools(context:)` 中创建 Tool 时注入，
    /// 保证 Tool 持有生命周期一致的单实例。
    public let manager: TaskStateManager

    public static let info = LumiAgentToolInfo(
        id: "list_tasks",
        displayName: LumiPluginLocalization.string("List Tasks", bundle: .module),
        description: LumiPluginLocalization.string(
            "Get the task list for the current conversation. Returns all tasks with their IDs, titles, statuses, and details. Use this to review full task information for decision-making, such as determining whether to append new tasks.",
            bundle: .module
        )
    )

    public init(manager: TaskStateManager) {
        self.manager = manager
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "status": .object([
                    "type": .string("string"),
                    "description": .string("Optional filter by status: 'pending', 'in_progress', 'completed', 'skipped'. Omit to return all tasks."),
                    "enum": .array([.string("pending"), .string("in_progress"), .string("completed"), .string("skipped")])
                ])
            ]),
            "required": .array([])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "列出任务" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationID.uuidString
        let manager = self.manager

        let tasks: [TaskItem]
        if let statusString = arguments["status"]?.stringValue,
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
