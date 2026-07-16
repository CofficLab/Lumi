import Foundation
import LumiCoreKit
import SuperLogKit

/// 查询 Goal 进度工具
///
/// 用于查询指定 Goal 的当前进度和详细信息。
public struct GetGoalProgressTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "get_goal_progress",
        displayName: "Get Goal Progress",
        description: """
        Query the current progress and details of a specific goal, including all its tasks and their statuses.
        """
    )

    public init() {}
    
    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "goal_id": .object([
                    "type": .string("string"),
                    "description": .string("ID of the goal to query"),
                    "minLength": .int(1)
                ])
            ]),
            "required": .array([.string("goal_id")])
        ])
    }
    
    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Get goal progress" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }
    
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        
        guard let goalId = arguments["goal_id"]?.anyValue as? String else {
            return "Error: goal_id is required"
        }
        
        guard let manager = await GoalTaskPlugin.currentManager() else {
            return "Error: goal task manager is not initialized"
        }

        guard let goal = await manager.fetchGoal(id: goalId) else {
            return "Error: goal not found"
        }
        
        let tasks = await manager.fetchTasks(goalId: goalId)
        
        let total = tasks.count
        let completed = tasks.filter { $0.status == .completed }.count
        let skipped = tasks.filter { $0.status == .skipped }.count
        let failed = tasks.filter { $0.status == .failed }.count
        let inProgress = tasks.filter { $0.status == .inProgress }.count
        let pending = tasks.filter { $0.status == .pending }.count
        
        let percent = total > 0 ? Int(Double(completed + skipped) / Double(total) * 100) : 0
        
        var output = "## 🎯 \(goal.title)\n"
        output += "**Status:** \(goal.status.rawValue)\n"
        if let desc = goal.goalDescription {
            output += "**Description:** \(desc)\n"
        }
        output += "\n"
        output += "**Progress:** \(completed + skipped)/\(total) (\(percent)%)\n"
        output += "- Completed: \(completed)\n"
        output += "- Skipped: \(skipped)\n"
        output += "- Failed: \(failed)\n"
        output += "- In Progress: \(inProgress)\n"
        output += "- Pending: \(pending)\n\n"
        
        if !tasks.isEmpty {
            output += "**Tasks:**\n"
            for (index, task) in tasks.enumerated() {
                let icon: String
                switch task.status {
                case .completed: icon = "✅"
                case .inProgress: icon = "▶️"
                case .failed: icon = "❌"
                case .skipped: icon = "⏭️"
                case .pending: icon = "⏳"
                }
                output += "\(index + 1). \(icon) \(task.title) [\(task.status.rawValue)]\n"
            }
        }
        
        return output
    }
}