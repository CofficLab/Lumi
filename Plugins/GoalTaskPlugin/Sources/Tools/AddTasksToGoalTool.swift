import Foundation
import LumiCoreKit
import SuperLogKit

/// 向已有 Goal 追加 Tasks 工具
///
/// 用于在执行过程中动态添加新任务到现有 Goal。
public struct AddTasksToGoalTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "➕"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "add_tasks_to_goal",
        displayName: "Add Tasks To Goal",
        description: """
        Add new tasks to an existing goal. Use this when you discover additional steps needed during execution.
        """
    )

    public init() {}
    
    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "goal_id": .object([
                    "type": .string("string"),
                    "description": .string("ID of the goal to add tasks to"),
                    "minLength": .int(1)
                ]),
                "tasks": .object([
                    "type": .string("array"),
                    "description": .string("Array of new tasks to add"),
                    "minItems": .int(1),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "title": .object([
                                "type": .string("string"),
                                "description": .string("Short, actionable task title"),
                                "minLength": .int(1)
                            ]),
                            "description": .object([
                                "type": .string("string"),
                                "description": .string("Detailed description of the task")
                            ]),
                            "executionContext": .object([
                                "type": .string("string"),
                                "description": .string("Technical context")
                            ]),
                            "parallelGroup": .object([
                                "type": .string("string"),
                                "description": .string("Optional parallel group identifier")
                            ])
                        ]),
                        "required": .array([.string("title")])
                    ])
                ])
            ]),
            "required": .array([.string("goal_id"), .string("tasks")])
        ])
    }
    
    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Add tasks to goal" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }
    
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        
        guard let goalId = arguments["goal_id"]?.anyValue as? String else {
            return "Error: goal_id is required"
        }
        
        guard let tasksArray = arguments["tasks"]?.anyValue as? [[String: Any]] else {
            return "Error: tasks array is required"
        }
        
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
        
        let createdTasks: [GoalTask]
        do {
            createdTasks = try await manager.addTasksToGoal(goalId: goalId, tasks: taskInputs)
        } catch {
            return "Error: failed to add tasks: \(error.localizedDescription)"
        }
        
        // 通知 UI
        if let goal = await manager.fetchGoal(id: goalId) {
            NotificationCenter.default.post(
                name: .goalDidChange,
                object: nil,
                userInfo: ["conversationId": goal.conversationId]
            )
        }
        
        var output = "✅ Added \(createdTasks.count) tasks to goal\n\n"
        for (index, task) in createdTasks.enumerated() {
            output += "\(index + 1). [\(task.id)] **\(task.title)**\n"
        }
        
        return output
    }
}