import Foundation
import LumiCoreKit
import SuperLogKit

/// 创建任务工具
///
/// 用于创建单个任务或批量创建任务列表。
/// 当用户提出复杂目标时，Agent 调用此工具将目标拆解为可执行的子任务。
public struct CreateTaskTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "create_task",
        displayName: LumiPluginLocalization.string("Create Task", bundle: .module),
        description: LumiPluginLocalization.string(
            "Create tasks for a complex goal. When the user asks you to do something that requires multiple steps, break it down into tasks using this tool. You can create a single task or a batch of tasks at once. Each task should be a concrete, actionable step. Tasks are tracked in a kanban board and you will be reminded of progress automatically. After creating tasks, start working on the first one immediately.",
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
                    "description": .string("Array of tasks to create. Each task has a title and optional detail."),
                    "minItems": .int(1),
                    "maxItems": .int(TaskStateManager.maxTasksPerConversation),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "title": .object([
                                "type": .string("string"),
                                "description": .string("Short, actionable task title (e.g., 'Setup project structure')"),
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

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "创建任务" }
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

        let manager = TaskStateManager.shared
        let createdTasks: [TaskItem]
        do {
            createdTasks = try await manager.createTasks(conversationId: conversationId, items: items)
        } catch {
            AutoTaskPlugin.logger.error("\(Self.t)Failed to create tasks for cid=\(conversationId.prefix(8)): \(error.localizedDescription)")
            return String(
                format: LumiPluginLocalization.string("Error: failed to save tasks: %@", bundle: .module),
                error.localizedDescription
            )
        }

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)Created \(items.count) tasks, posting autoTaskDidChange for cid=\(conversationId.prefix(8))")
        }

        // 通知 UI 刷新
        NotificationCenter.default.post(
            name: .autoTaskDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )

        let createdLabel = String(
            format: LumiPluginLocalization.string("Created %lld tasks:", bundle: .module),
            createdTasks.count
        )
        var result = "✅ \(createdLabel)\n\n"
        for (index, task) in createdTasks.enumerated() {
            result += "\(index + 1). [\(task.id)] **\(task.title)**"
            if let detail = task.detail {
                result += "\n   \(detail)"
            }
            result += "\n"
        }
        let firstTask = createdTasks.first!
        let firstTaskLabel = "[\(firstTask.id)] \(firstTask.title)"
        let startLabel = String(
            format: LumiPluginLocalization.string("Now start working on task #1: %@", bundle: .module),
            firstTaskLabel
        )
        result += "\n\(startLabel)"

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)Created \(items.count) tasks for conversation \(conversationId)")
        }

        return result
    }
}
