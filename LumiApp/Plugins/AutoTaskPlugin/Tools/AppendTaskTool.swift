import Foundation
import AgentToolKit

/// 追加任务工具
///
/// 在已有任务列表末尾追加新任务，不影响已有任务的状态和顺序。
/// 适用于 Agent 在执行过程中发现需要额外步骤的场景。
struct AppendTaskTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false

    let name = "append_task"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "追加新任务到已有任务列表末尾。当执行过程中发现需要额外步骤时，使用此工具添加新任务。不会影响已有任务的状态。"
        case .english:
            return """
    Append new tasks to the end of the existing task list. Use this when you discover \
    additional steps are needed during execution. Existing tasks and their statuses are not affected.
    """
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "tasks": [
                    "type": "array",
                    "description": "Array of tasks to append. Each task has a title and optional detail.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": [
                                "type": "string",
                                "description": "Short, actionable task title",
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

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        String(localized: "Error: missing tool execution context", table: "AutoTask")
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationId.uuidString

        guard let tasksArray = arguments["tasks"]?.value as? [[String: Any]] else {
            return String(localized: "Error: tasks array is required", table: "AutoTask")
        }

        guard !tasksArray.isEmpty else {
            return String(localized: "Error: tasks array must not be empty", table: "AutoTask")
        }

        let items: [(title: String, detail: String?)] = tasksArray.compactMap { item in
            guard let title = item["title"] as? String, !title.isEmpty else { return nil }
            let detail = item["detail"] as? String
            return (title: title, detail: detail)
        }

        guard !items.isEmpty else {
            return String(localized: "Error: no valid tasks found (each task needs a non-empty title)", table: "AutoTask")
        }

        let manager = TaskStateManager.shared
        let appendedTasks = await manager.appendTasks(conversationId: conversationId, items: items)

        if AutoTaskPlugin.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)Appended \(items.count) tasks for cid=\(conversationId.prefix(8))")
        }

        // 通知 UI 刷新
        NotificationCenter.default.post(
            name: .autoTaskDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )

        var result = "✅ \(String(localized: "Appended \(items.count) tasks:", table: "AutoTask")) \n\n"
        for task in appendedTasks {
            result += "\(task.order). [\(task.id)] **\(task.title)**"
            if let detail = task.detail {
                result += "\n   \(detail)"
            }
            result += "\n"
        }

        if Self.verbose {
            if AutoTaskPlugin.verbose {
                AutoTaskPlugin.logger.info("\(Self.t)Appended \(items.count) tasks for conversation \(conversationId)")
            }
        }

        return result
    }
}
