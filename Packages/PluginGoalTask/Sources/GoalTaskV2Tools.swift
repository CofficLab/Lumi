import KitAgentTool
import Foundation
import ProviderConversation

private enum GoalTaskToolSupport {
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
}

public struct CreateGoalV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "create_goal"
    public let name = toolName
    public init(conversations: (any ConversationManaging)? = nil) { _ = conversations }
    public func description(for language: LanguagePreference) -> String { "Create a goal with tasks for complex, multi-step work. Only one unfinished goal is allowed per conversation." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["title": ["type": "string", "description": "Short goal title", "minLength": 1], "description": ["type": "string", "description": "Detailed goal description"], "successCriteria": ["type": "string", "description": "Optional completion criteria"], "tasks": GoalTaskToolSupport.taskSchema(maxItems: GoalStateManager.maxTasksPerGoal)], "required": ["title", "tasks"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Create goal" }

    /// A goal must be created in the conversation that owns the current Agent
    /// turn. The UI selection is deliberately not used here: the user may
    /// switch conversations while a background turn is still executing.
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(
            toolName: name,
            reason: "create_goal requires an Agent execution context"
        )
    }

    /// Context-aware entry point used by the real ToolManager. The context is
    /// created from the ToolJob's conversation ID, which is captured when the
    /// AgentLoop emits the tool call.
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(
            conversationID: context.conversationID,
            arguments: arguments
        ))
    }

    private func execute(
        conversationID: UUID,
        arguments: [String: ToolArgument]
    ) async throws -> String {
        guard let title = GoalTaskToolSupport.string(arguments, "title"), !title.isEmpty else { return "Error: title is required" }
        guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        let conversationId = conversationID.uuidString
        let tasks = GoalTaskToolSupport.taskInputs(arguments["tasks"]?.value)
        guard !tasks.isEmpty else { return "Error: no valid tasks found" }
        let existingGoals = await manager.fetchGoals(conversationId: conversationId)
        if let active = existingGoals.first(where: { ![Goal.GoalStatus.completed, .failed, .skipped].contains($0.status) }) {
            return "⚠️ Cannot create new goal: there is an unfinished goal.\n\n**Current goal:** \(active.title)\n**Status:** \(active.status.rawValue)\n\nComplete or skip it with `update_goal_status` before creating another goal."
        }
        do {
            let result = try await manager.createGoal(conversationId: conversationId, title: title, description: GoalTaskToolSupport.string(arguments, "description"), successCriteria: GoalTaskToolSupport.string(arguments, "successCriteria"), tasks: tasks)
            GoalTaskToolSupport.changed(conversationId)
            let items = result.tasks.enumerated().map { "\($0.offset + 1). \($0.element.status == .inProgress ? "▶️" : "⏳") [\($0.element.id)] **\($0.element.title)**" }.joined(separator: "\n")
            return "✅ Created goal: **\(result.goal.title)**\n\n**Tasks (\(result.tasks.count)):**\n\(items)\n\nNow start working on the first task (or first parallel group)."
        } catch { return "Error: failed to create goal: \(error.localizedDescription)" }
    }
}

public struct AddTasksToGoalV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "add_tasks_to_goal"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Add new tasks to an existing goal when more work is discovered." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["goal_id": ["type": "string", "minLength": 1], "tasks": GoalTaskToolSupport.taskSchema()], "required": ["goal_id", "tasks"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Add tasks to goal" }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let goalId = GoalTaskToolSupport.string(arguments, "goal_id"), !goalId.isEmpty else { return "Error: goal_id is required" }
        guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        let inputs = GoalTaskToolSupport.taskInputs(arguments["tasks"]?.value); guard !inputs.isEmpty else { return "Error: no valid tasks found" }
        do {
            let tasks = try await manager.addTasksToGoal(goalId: goalId, tasks: inputs)
            if let goal = await manager.fetchGoal(id: goalId) { await manager.resetContinuationCount(conversationId: goal.conversationId); GoalTaskToolSupport.changed(goal.conversationId) }
            return "✅ Added \(tasks.count) tasks to goal\n\n" + tasks.enumerated().map { "\($0.offset + 1). [\($0.element.id)] **\($0.element.title)**" }.joined(separator: "\n")
        } catch { return "Error: failed to add tasks: \(error.localizedDescription)" }
    }
}

public struct GetGoalProgressV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "get_goal_progress"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Query a goal's progress, tasks, and statuses." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["goal_id": ["type": "string", "minLength": 1]], "required": ["goal_id"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Get goal progress" }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let goalId = GoalTaskToolSupport.string(arguments, "goal_id"), let manager = GoalTaskToolSupport.manager() else { return "Error: goal_id is required" }
        guard let goal = await manager.fetchGoal(id: goalId) else { return "Error: goal not found" }
        let tasks = await manager.fetchTasks(goalId: goalId); let completed = tasks.filter { $0.status == .completed }.count; let skipped = tasks.filter { $0.status == .skipped }.count; let failed = tasks.filter { $0.status == .failed }.count; let active = tasks.filter { $0.status == .inProgress }.count; let pending = tasks.filter { $0.status == .pending }.count
        let progress = tasks.isEmpty ? 0 : Int(Double(completed + skipped) / Double(tasks.count) * 100)
        let rows = tasks.enumerated().map { index, task in "\(index + 1). \(icon(task.status)) \(task.title) [\(task.status.rawValue)]" }.joined(separator: "\n")
        return "## 🎯 \(goal.title)\n**Status:** \(goal.status.rawValue)\n\n**Progress:** \(completed + skipped)/\(tasks.count) (\(progress)%)\n- Completed: \(completed)\n- Skipped: \(skipped)\n- Failed: \(failed)\n- In Progress: \(active)\n- Pending: \(pending)\n\n**Tasks:**\n\(rows)"
    }
    private func icon(_ status: GoalTask.TaskStatus) -> String { switch status { case .completed: "✅"; case .inProgress: "▶️"; case .failed: "❌"; case .skipped: "⏭️"; case .pending: "⏳" } }
}

public struct UpdateGoalStatusV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "update_goal_status"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Update a goal's status, including blocked or failed reasons." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["goal_id": ["type": "string", "minLength": 1], "status": ["type": "string", "enum": GoalTaskToolSupport.goalStatuses], "blocked_reason": ["type": "string"], "failure_reason": ["type": "string"], "suggested_actions": ["type": "array", "items": ["type": "string"]]], "required": ["goal_id", "status"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Update goal status" }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let goalId = GoalTaskToolSupport.string(arguments, "goal_id"), let value = GoalTaskToolSupport.string(arguments, "status"), let status = Goal.GoalStatus(rawValue: value) else { return "Error: invalid status" }; guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        do { let goal = try await manager.updateGoalStatus(id: goalId, status: status, blockedReason: GoalTaskToolSupport.string(arguments, "blocked_reason"), failureReason: GoalTaskToolSupport.string(arguments, "failure_reason")); GoalTaskToolSupport.changed(goal.conversationId); return "✅ Goal **\(goal.title)** updated to **\(status.rawValue)**" } catch { return "Error: failed to update goal: \(error.localizedDescription)" }
    }
}

public struct UpdateTaskStatusV2Tool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "update_task_status"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Update one task's status and recalculate its parent goal." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["task_id": ["type": "string", "minLength": 1], "status": ["type": "string", "enum": GoalTaskToolSupport.taskStatuses], "result": ["type": "string"], "error_message": ["type": "string"]], "required": ["task_id", "status"]] }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Update task status" }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let taskId = GoalTaskToolSupport.string(arguments, "task_id"), let value = GoalTaskToolSupport.string(arguments, "status"), let status = GoalTask.TaskStatus(rawValue: value) else { return "Error: invalid status" }; guard let manager = GoalTaskToolSupport.manager() else { return "Error: goal task manager is not initialized" }
        do { let result = try await manager.updateGoalTaskStatus(id: taskId, status: status, result: GoalTaskToolSupport.string(arguments, "result"), errorMessage: GoalTaskToolSupport.string(arguments, "error_message")); await manager.resetContinuationCount(conversationId: result.goal.conversationId); GoalTaskToolSupport.changed(result.goal.conversationId); return "✅ Task **\(result.task.title)** updated to **\(status.rawValue)**\n\nGoal **\(result.goal.title)** status: **\(result.goal.status.rawValue)**" } catch { return "Error: failed to update task: \(error.localizedDescription)" }
    }
}
