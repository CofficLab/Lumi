import Foundation
import AgentToolKit

/// 创建任务工具
///
/// 用于创建单个任务或批量创建任务列表。
/// 当用户提出复杂目标时，Agent 调用此工具将目标拆解为可执行的子任务。
struct CreateTaskTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false

    let name = "create_task"
    let conversationId: String
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "为复杂目标创建任务。当用户提出需要多步完成的请求时，使用此工具将其拆分为任务。可以一次创建单个任务或一批任务。每个任务都应是具体、可执行的步骤。任务会在看板中跟踪，并自动提醒进度。创建任务后，应立即开始处理第一个任务。"
        case .english:
            return     """
    Create tasks for a complex goal. When the user asks you to do something that requires multiple steps, \
    break it down into tasks using this tool. You can create a single task or a batch of tasks at once. \
    Each task should be a concrete, actionable step. Tasks are tracked in a kanban board and you will be \
    reminded of progress automatically. After creating tasks, start working on the first one immediately.
    """
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "tasks": [
                    "type": "array",
                    "description": "Array of tasks to create. Each task has a title and optional detail.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": [
                                "type": "string",
                                "description": "Short, actionable task title (e.g., 'Setup project structure')",
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
        await manager.createTasks(conversationId: conversationId, items: items)

        if AutoTaskPlugin.verbose {
                    AutoTaskPlugin.logger.info("\(Self.t)Created \(items.count) tasks, posting autoTaskDidChange for cid=\(conversationId.prefix(8))")
        }

        // 通知 UI 刷新
        NotificationCenter.default.post(
            name: .autoTaskDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )

        var result = "✅ \(String(localized: "Created", table: "AutoTask")) \(items.count) \(String(localized: "tasks:", table: "AutoTask"))\n\n"
        for (index, item) in items.enumerated() {
            result += "\(index + 1). **\(item.title)**"
            if let detail = item.detail {
                result += "\n   \(detail)"
            }
            result += "\n"
        }
        let startLabel = String(localized: "Now start working on task #1", table: "AutoTask")
        result += "\n\(startLabel): \(items[0].title)"

        if Self.verbose {
            if AutoTaskPlugin.verbose {
                            AutoTaskPlugin.logger.info("\(Self.t)Created \(items.count) tasks for conversation \(conversationId)")
            }
        }

        return result
    }
}
