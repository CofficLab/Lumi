import Foundation
import LumiCoreKit
import SuperLogKit

/// 更新 Task 状态工具
///
/// 用于更新单个 Task 的状态（completed/failed/skipped）。
/// 更新 Task 状态时会自动推导并更新所属 Goal 的状态。
public struct UpdateTaskStatusTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "update_task_status",
        displayName: "Update Task Status",
        description: """
        Update the status of a specific task. Use this to mark a task as:
        - "completed": Task finished successfully
        - "failed": Task encountered an unrecoverable error
        - "skipped": Task is no longer needed
        - "in_progress": Task is currently being worked on

        When you update a task's status, the parent goal's status will be automatically recalculated.
        """
    )

    public init() {}
    
    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task_id": .object([
                    "type": .string("string"),
                    "description": .string("ID of the task to update"),
                    "minLength": .int(1)
                ]),
                "status": .object([
                    "type": .string("string"),
                    "description": .string("New status for the task"),
                    "enum": .array([.string("pending"), .string("in_progress"), .string("completed"), .string("failed"), .string("skipped")])
                ]),
                "result": .object([
                    "type": .string("string"),
                    "description": .string("Optional summary of the task result (for completed tasks)")
                ]),
                "error_message": .object([
                    "type": .string("string"),
                    "description": .string("Optional error message (for failed tasks)")
                ])
            ]),
            "required": .array([.string("task_id"), .string("status")])
        ])
    }
    
    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Update task status" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }
    
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        
        guard let taskId = arguments["task_id"]?.anyValue as? String else {
            return "Error: task_id is required"
        }
        
        guard let statusString = arguments["status"]?.anyValue as? String,
              let status = GoalTask.TaskStatus(rawValue: statusString) else {
            return "Error: invalid status"
        }
        
        let result = arguments["result"]?.anyValue as? String
        let errorMessage = arguments["error_message"]?.anyValue as? String

        guard let manager = await GoalTaskPlugin.currentManager() else {
            return "Error: goal task manager is not initialized"
        }
        
        let updateResult: (task: GoalTask, goal: Goal)
        do {
            updateResult = try await manager.updateGoalTaskStatus(
                id: taskId,
                status: status,
                result: result,
                errorMessage: errorMessage
            )
        } catch {
            return "Error: failed to update task: \(error.localizedDescription)"
        }
        
        // 通知 UI 刷新
        NotificationCenter.default.post(
            name: .goalDidChange,
            object: nil,
            userInfo: ["conversationId": updateResult.goal.conversationId]
        )
        
        // 检查 Goal 状态变化
        var output = "✅ Task **\(updateResult.task.title)** updated to **\(status.rawValue)**\n"
        output += "\nGoal **\(updateResult.goal.title)** status: **\(updateResult.goal.status.rawValue)**"
        
        if updateResult.goal.status == .completed {
            output += "\n\n🎉 Goal completed!"
        } else if updateResult.goal.status == .failed {
            output += "\n\n❌ Goal failed."
        }
        
        return output
    }
}