import Foundation

struct CreateBackgroundAgentTaskTool: AgentTool {
    let name: String = "create_background_agent_task"
    let description: String = String(localized: "Create a background agent task to execute user instructions asynchronously. Suitable for long-running tasks that don't require real-time attention.", table: "BackgroundAgentTask")

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "instruction": [
                    "type": "string",
                    "description": String(localized: "User instruction to execute in background.", table: "BackgroundAgentTask")
                ]
            ],
            "required": ["instruction"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let instruction = (arguments["instruction"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !instruction.isEmpty else {
            throw NSError(
                domain: "CreateBackgroundAgentTaskTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "instruction cannot be empty", table: "BackgroundAgentTask")]
            )
        }

        // 🎯 只负责创建任务，存储层会自动发布事件
        let taskId = BackgroundAgentTaskStore.shared.enqueue(prompt: instruction)

        let response: [String: Any] = [
            "task_id": taskId.uuidString,
            "status": "pending",
            "message": String(localized: "Background Agent task created. The system will process this instruction in the background. You can check the task status and results later in the status bar.", table: "BackgroundAgentTask")
        ]

        let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"task_id\":\"\(taskId.uuidString)\",\"status\":\"pending\"}"
    }
}
