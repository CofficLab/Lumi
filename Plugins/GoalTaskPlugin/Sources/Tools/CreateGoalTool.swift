import Foundation
import LumiCoreKit
import SuperLogKit

/// 创建 Goal 工具
///
/// 用于创建一个新的目标及其关联的 Task 列表。
/// 当用户提出复杂目标时，Agent 调用此工具将目标拆解为可执行的子任务。
public struct CreateGoalTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🎯"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "create_goal",
        displayName: "Create Goal",
        description: """
        Create a goal with associated tasks for a complex objective. Use this when:
        - The user's request requires 2+ steps to complete
        - The work may span multiple conversation turns
        - You want to track progress systematically
        - You want to identify parallel execution opportunities

        The goal represents the overall objective (with optional success criteria), and each task is a concrete step. Tasks can be grouped into parallel groups for concurrent execution.

        After creating a goal, start working on the first task (or first parallel group) immediately.
        """
    )

    public init() {}
    
    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Short title of the goal (e.g., 'Build user authentication system')"),
                    "minLength": .int(1)
                ]),
                "description": .object([
                    "type": .string("string"),
                    "description": .string("Detailed description of the goal and what it aims to achieve")
                ]),
                "successCriteria": .object([
                    "type": .string("string"),
                    "description": .string("Optional criteria that define when this goal is considered successfully completed")
                ]),
                "tasks": .object([
                    "type": .string("array"),
                    "description": .string("Array of tasks to execute for this goal"),
                    "minItems": .int(1),
                    "maxItems": .int(GoalStateManager.maxTasksPerGoal),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "title": .object([
                                "type": .string("string"),
                                "description": .string("Short, actionable task title (shown to user)"),
                                "minLength": .int(1)
                            ]),
                            "description": .object([
                                "type": .string("string"),
                                "description": .string("Detailed description of the task (for your reference, not shown to user)")
                            ]),
                            "executionContext": .object([
                                "type": .string("string"),
                                "description": .string("Technical context like file paths, API endpoints, dependencies (for your reference)")
                            ]),
                            "parallelGroup": .object([
                                "type": .string("string"),
                                "description": .string("Optional group identifier. Tasks with the same group can be executed in parallel")
                            ])
                        ]),
                        "required": .array([.string("title")])
                    ])
                ])
            ]),
            "required": .array([.string("title"), .string("tasks")])
        ])
    }
    
    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Create goal" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }
    
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationID.uuidString
        
        guard let title = arguments["title"]?.anyValue as? String, !title.isEmpty else {
            return "Error: title is required"
        }
        
        let description = arguments["description"]?.anyValue as? String
        let successCriteria = arguments["successCriteria"]?.anyValue as? String
        
        guard let tasksArray = arguments["tasks"]?.anyValue as? [[String: Any]] else {
            return "Error: tasks array is required"
        }
        
        guard !tasksArray.isEmpty else {
            return "Error: tasks array must not be empty"
        }
        
        // 解析 tasks
        var taskInputs: [(title: String, description: String?, executionContext: String?, parallelGroup: String?)] = []
        for taskDict in tasksArray {
            guard let taskTitle = taskDict["title"] as? String, !taskTitle.isEmpty else {
                continue
            }
            let taskDesc = taskDict["description"] as? String
            let taskContext = taskDict["executionContext"] as? String
            let taskGroup = taskDict["parallelGroup"] as? String
            taskInputs.append((taskTitle, taskDesc, taskContext, taskGroup))
        }
        
        guard !taskInputs.isEmpty else {
            return "Error: no valid tasks found"
        }
        
        guard let manager = await GoalTaskPlugin.currentManager() else {
            return "Error: goal task manager is not initialized"
        }
        
        // 创建 Goal
        let result: (goal: Goal, tasks: [GoalTask])
        do {
            result = try await manager.createGoal(
                conversationId: conversationId,
                title: title,
                description: description,
                successCriteria: successCriteria,
                tasks: taskInputs
            )
        } catch {
            GoalTaskPlugin.logger.error("Failed to create goal: \(error.localizedDescription)")
            return "Error: failed to create goal: \(error.localizedDescription)"
        }
        
        // 通知 UI 刷新
        NotificationCenter.default.post(
            name: .goalDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
        
        // 构建返回消息
        var output = "✅ Created goal: **\(result.goal.title)**\n"
        if let desc = result.goal.goalDescription {
            output += "_\(desc)_\n"
        }
        output += "\n"
        output += "**Tasks (\(result.tasks.count)):**\n"
        for (index, task) in result.tasks.enumerated() {
            let statusIcon = task.status == .inProgress ? "▶️" : "⏳"
            let groupMark = task.parallelGroup != nil ? " [parallel: \(task.parallelGroup!)]" : ""
            output += "\(index + 1). \(statusIcon) [\(task.id)] **\(task.title)**\(groupMark)\n"
        }
        
        output += "\nNow start working on the first task (or first parallel group)."
        
        return output
    }
}