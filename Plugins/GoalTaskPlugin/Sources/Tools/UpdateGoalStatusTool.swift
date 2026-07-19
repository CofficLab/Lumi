import Foundation
import LumiKernel
import SuperLogKit

/// 更新 Goal 状态工具
///
/// 用于手动更新 Goal 的状态，特别是标记为 blocked/failed。
/// 当 LLM 发现目标无法实现时，应调用此工具标记为 blocked 并提供原因。
public struct UpdateGoalStatusTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🎯"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "update_goal_status",
        displayName: "Update Goal Status",
        description: """
        Manually update a goal's status. Use this when:
        - You discover the goal is unachievable (set to "blocked" or "failed")
        - You need to ask the user for clarification before continuing

        **Important:** When you set status to "blocked", you MUST:
        1. Provide a clear reason in "blocked_reason"
        2. Optionally suggest actions in "suggested_actions"
        3. Stop executing tasks and wait for user input

        The user will see a notification and can decide how to proceed.
        """
    )

    public init() {}
    
    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "goal_id": .object([
                    "type": .string("string"),
                    "description": .string("ID of the goal to update"),
                    "minLength": .int(1)
                ]),
                "status": .object([
                    "type": .string("string"),
                    "description": .string("New status for the goal"),
                    "enum": .array([.string("pending"), .string("in_progress"), .string("completed"), .string("blocked"), .string("failed"), .string("skipped")])
                ]),
                "blocked_reason": .object([
                    "type": .string("string"),
                    "description": .string("Why the goal is blocked (when status = blocked)")
                ]),
                "failure_reason": .object([
                    "type": .string("string"),
                    "description": .string("Why the goal failed (when status = failed)")
                ]),
                "suggested_actions": .object([
                    "type": .string("array"),
                    "description": .string("Optional list of suggested actions for the user to choose from"),
                    "items": .object([
                        "type": .string("string")
                    ])
                ])
            ]),
            "required": .array([.string("goal_id"), .string("status")])
        ])
    }
    
    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Update goal status" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }
    
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        
        guard let goalId = arguments["goal_id"]?.anyValue as? String else {
            return "Error: goal_id is required"
        }
        
        guard let statusString = arguments["status"]?.anyValue as? String,
              let status = Goal.GoalStatus(rawValue: statusString) else {
            return "Error: invalid status"
        }
        
        let blockedReason = arguments["blocked_reason"]?.anyValue as? String
        let failureReason = arguments["failure_reason"]?.anyValue as? String
        let suggestedActions = arguments["suggested_actions"]?.anyValue as? [String]
        
        guard let manager = await GoalTaskPlugin.currentManager() else {
            return "Error: goal task manager is not initialized"
        }
        
        let goal: Goal
        do {
            goal = try await manager.updateGoalStatus(
                id: goalId,
                status: status,
                blockedReason: blockedReason,
                failureReason: failureReason
            )
        } catch {
            return "Error: failed to update goal: \(error.localizedDescription)"
        }
        
        // 通知 UI 刷新
        NotificationCenter.default.post(
            name: .goalDidChange,
            object: nil,
            userInfo: ["conversationId": goal.conversationId]
        )
        
        // 构建返回消息
        var output = "✅ Goal **\(goal.title)** updated to **\(status.rawValue)**\n"
        
        if status == .blocked {
            output += "\n⚠️ **This goal is now blocked.**\n"
            if let reason = blockedReason {
                output += "Reason: \(reason)\n"
            }
            if let actions = suggestedActions, !actions.isEmpty {
                output += "\n**Suggested actions for the user:**\n"
                for (index, action) in actions.enumerated() {
                    output += "\(index + 1). \(action)\n"
                }
            }
            output += "\nWaiting for user input on how to proceed."
        }
        
        return output
    }
}