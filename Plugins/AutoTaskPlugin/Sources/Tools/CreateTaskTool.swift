import AgentToolKit
import Foundation
import SuperLogKit
import LumiCoreKit

/// 创建任务工具
///
/// 用于创建单个任务或批量创建任务列表。
/// 当用户提出复杂目标时，Agent 调用此工具将目标拆解为可执行的子任务。
public struct CreateTaskTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    public let name = "create_task"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "为复杂目标创建任务。当用户提出需要多步完成的请求时，使用此工具将其拆分为任务。可以一次创建单个任务或一批任务。每个任务都应是具体、可执行的步骤。任务会在看板中跟踪，并自动提醒进度。创建任务后，应立即开始处理第一个任务。"
        case .english:
            return """
    Create tasks for a complex goal. When the user asks you to do something that requires multiple steps, \
    break it down into tasks using this tool. You can create a single task or a batch of tasks at once. \
    Each task should be a concrete, actionable step. Tasks are tracked in a kanban board and you will be \
    reminded of progress automatically. After creating tasks, start working on the first one immediately.
    """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "tasks": [
                    "type": "array",
                    "description": "Array of tasks to create. Each task has a title and optional detail.",
                    "minItems": 1,
                    "maxItems": TaskStateManager.maxTasksPerConversation,
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": [
                                "type": "string",
                                "description": "Short, actionable task title (e.g., 'Setup project structure')",
                                "minLength": 1,
                            ],
                            "detail": [
                                "type": "string",
                                "description": "Optional detailed description of what this task involves",
                            ],
                        ],
                        "required": ["title"],
                    ],
                ],
            ],
            "required": ["tasks"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "创建任务" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationId.uuidString

        guard let tasksArray = arguments["tasks"]?.value as? [[String: Any]] else {
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
