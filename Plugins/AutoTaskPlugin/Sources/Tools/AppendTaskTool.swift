import Foundation
import LumiCoreKit
import SuperLogKit

/// 追加任务工具
///
/// 在已有任务列表末尾追加新任务，不影响已有任务的状态和顺序。
/// 适用于 Agent 在执行过程中发现需要额外步骤的场景。
public struct AppendTaskTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    /// 可注入的状态管理器（用于测试）。nil 时使用全局共享实例。
    public var manager: TaskStateManager?

    public static let info = LumiAgentToolInfo(
        id: "append_task",
        displayName: LumiPluginLocalization.string("Append Task", bundle: .module),
        description: LumiPluginLocalization.string(
            "Append new tasks to the end of the existing task list. Use this when you discover additional steps are needed during execution. Existing tasks and their statuses are not affected.",
            bundle: .module
        )
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "tasks": .object([
                    "type": .string("array"),
                    "description": .string("Array of tasks to append. Each task has a title and optional detail."),
                    "minItems": .int(1),
                    "maxItems": .int(TaskStateManager.maxTasksPerConversation),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "title": .object([
                                "type": .string("string"),
                                "description": .string("Short, actionable task title"),
                                "minLength": .int(1)
                            ]),
                            "detail": .object([
                                "type": .string("string"),
                                "description": .string("Optional detailed description of what this task involves")
                            ])
                        ]),
                        "required": .array([.string("title")])
                    ])
                ])
            ]),
            "required": .array([.string("tasks")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "追加任务" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationID.uuidString

        guard let tasksArray = arguments["tasks"]?.anyValue as? [[String: Any]] else {
            return LumiPluginLocalization.string("Error: tasks array is required", bundle: .module)
        }

        guard !tasksArray.isEmpty else {
            return LumiPluginLocalization.string("Error: tasks array must not be empty", bundle: .module)
        }

        let items = TaskToolInputNormalizer.normalize(tasksArray)

        guard !items.isEmpty else {
            return LumiPluginLocalization.string("Error: no valid tasks found (each task needs a non-empty title)", bundle: .module)
        }

        let manager = manager ?? .shared
        let appendedTasks: [TaskItem]
        do {
            appendedTasks = try await manager.appendTasks(conversationId: conversationId, items: items)
        } catch {
            AutoTaskPlugin.logger.error("\(Self.t)Failed to append tasks for cid=\(conversationId.prefix(8)): \(error.localizedDescription)")
            return String(
                format: LumiPluginLocalization.string("Error: failed to save tasks: %@", bundle: .module),
                error.localizedDescription
            )
        }

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)Appended \(appendedTasks.count) tasks for cid=\(conversationId.prefix(8))")
        }

        guard !appendedTasks.isEmpty else {
            return LumiPluginLocalization.string("No tasks appended: task list already reached the maximum size.", bundle: .module)
        }

        // 通知 UI 刷新
        NotificationCenter.default.post(
            name: .taskDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )

        let appendedLabel = String(
            format: LumiPluginLocalization.string("Appended %lld tasks:", bundle: .module),
            appendedTasks.count
        )
        var result = "✅ \(appendedLabel)\n\n"
        for task in appendedTasks {
            result += "\(task.order). [\(task.id)] **\(task.title)**"
            if let detail = task.detail {
                result += "\n   \(detail)"
            }
            result += "\n"
        }

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)Appended \(appendedTasks.count) tasks for conversation \(conversationId)")
        }

        return result
    }
}
