import Foundation

struct CreateBackgroundAgentTaskTool: AgentTool {
    let name: String = "create_background_agent_task"
    let description: String = "接收一条用户指令，将其保存为后台 Agent 任务并在后台异步执行。适用于需要长时间运行或不需要前台实时关注的任务。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "instruction": [
                    "type": "string",
                    "description": "用户希望在后台执行的自然语言指令。"
                ]
            ],
            "required": ["instruction"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let instruction = (arguments["instruction"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !instruction.isEmpty else {
            throw NSError(
                domain: "CreateBackgroundAgentTaskTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "instruction 不能为空"]
            )
        }

        let taskId = BackgroundAgentTaskStore.shared.enqueue(prompt: instruction)

        let response: [String: Any] = [
            "task_id": taskId.uuidString,
            "status": "pending",
            "message": "已创建后台 Agent 任务，系统会在后台继续处理此指令。你可以稍后在状态栏查看任务状态和结果。"
        ]

        let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"task_id\":\"\(taskId.uuidString)\",\"status\":\"pending\"}"
    }
}

