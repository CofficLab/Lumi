import KitAgentTool
import Foundation
import ProviderConversation

/// Goal 工具共享支持：参数解析、manager 获取、goal_id 解析。
///
/// 供 `Sources/Tools/` 下各工具复用（同模块 internal 访问）。
enum GoalTaskToolSupport {
    static let goalStatuses = ["pending", "in_progress", "completed", "blocked", "failed", "skipped"]
    static let taskStatuses = ["pending", "in_progress", "completed", "failed", "skipped"]

    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        (arguments[key]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func taskInputs(_ value: Any?) -> [(title: String, description: String?, executionContext: String?, parallelGroup: String?)] {
        guard let tasks = value as? [[String: Any]] else { return [] }
        return tasks.compactMap { task in
            guard let title = task["title"] as? String,
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return (title, task["description"] as? String, task["executionContext"] as? String, task["parallelGroup"] as? String)
        }
    }

    static func taskSchema(maxItems: Int? = nil) -> [String: Any] {
        var schema: [String: Any] = [
            "type": "array",
            "minItems": 1,
            "items": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "Short, actionable task title", "minLength": 1],
                    "description": ["type": "string", "description": "Detailed description of the task"],
                    "executionContext": ["type": "string", "description": "Technical context"],
                    "parallelGroup": ["type": "string", "description": "Optional parallel group identifier"],
                ],
                "required": ["title"],
            ],
        ]
        if let maxItems { schema["maxItems"] = maxItems }
        return schema
    }

    static func manager() -> GoalStateManager? { Plugin.currentManager() }
    static func changed(_ conversationId: String) {
        guard let conversationID = UUID(uuidString: conversationId) else { return }
        Task { @MainActor in
            GoalChangeCenter.shared.notify(conversationID: conversationID)
        }
    }

    // MARK: - goal_id resolution

    /// 解析失败时携带的面向模型的错误消息。
    struct GoalResolutionError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func goalListText(_ goals: [Goal]) -> String {
        goals.map { "- [\($0.id)] **\($0.title)** (\($0.status.rawValue))" }.joined(separator: "\n")
    }

    /// 解析 `goal_id`，按三级回退：
    /// 1. 精确 `goal.id` 匹配
    /// 2. 会话内 `goal.title` 精确匹配（忽略大小写与首尾空白）
    /// 3. 未提供 `goal_id` 时，解析会话内唯一活跃 goal
    ///
    /// 失败时返回面向模型的错误消息，**附本会话候选 goal 列表**，
    /// 避免 "goal not found" 不可恢复。
    static func resolveGoalId(
        raw: String?,
        conversationId: String?,
        manager: GoalStateManager
    ) async -> Result<String, GoalResolutionError> {
        var scoped: [Goal] = []
        if let conversationId { scoped = await manager.fetchGoals(conversationId: conversationId) }

        if let raw, !raw.isEmpty {
            if await manager.fetchGoal(id: raw) != nil { return .success(raw) }
            let normalized = normalize(raw)
            let byTitle = scoped.filter { normalize($0.title) == normalized }
            if byTitle.count == 1, let goal = byTitle.first { return .success(goal.id) }
            let candidates = byTitle.isEmpty ? scoped : byTitle
            return .failure(GoalResolutionError(message: """
            Error: goal not found: `\(raw)`

            Available goals in this conversation:
            \(candidates.isEmpty ? "- (none)" : goalListText(candidates))

            Tip: pass the exact `goal_id` shown in create_goal's **Goal ID** line (or one listed above). An exact goal title is also accepted.
            """))
        }

        let active = scoped.filter { ![Goal.GoalStatus.completed, .failed, .skipped].contains($0.status) }
        if active.count == 1, let goal = active.first { return .success(goal.id) }
        if active.isEmpty, scoped.count == 1, let goal = scoped.first { return .success(goal.id) }
        let reason = active.count > 1 ? "multiple active goals found" : "goal_id is required"
        return .failure(GoalResolutionError(message: """
        Error: \(reason).

        Available goals in this conversation:
        \(scoped.isEmpty ? "- (none)" : goalListText(scoped))

        Tip: pass a `goal_id` from create_goal's **Goal ID** line or one listed above.
        """))
    }
}
