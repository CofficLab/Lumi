import Foundation

struct ListBackgroundAgentTasksTool: AgentTool {
    let name: String = "list_background_agent_tasks"
    let description: String = "列出最近的后台 Agent 任务及其状态，供你了解有哪些任务正在运行或已经完成。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": "最多返回多少条任务记录，默认 20。",
                    "minimum": 1,
                    "maximum": 100
                ]
            ]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let limitValue = arguments["limit"]?.value as? Int
        let limit: Int
        if let v = limitValue, v > 0 {
            limit = min(v, 100)
        } else {
            limit = 20
        }

        let tasks = BackgroundAgentTaskStore.shared.fetchRecent(limit: limit)

        let payload: [[String: Any]] = tasks.map { task in
            var dict: [String: Any] = [
                "id": task.id.uuidString,
                "status": BackgroundAgentTaskStatus(rawOrDefault: task.statusRawValue).rawValue,
                "original_prompt": task.originalPrompt,
                "created_at": task.createdAt.timeIntervalSince1970
            ]
            if let startedAt = task.startedAt {
                dict["started_at"] = startedAt.timeIntervalSince1970
            }
            if let finishedAt = task.finishedAt {
                dict["finished_at"] = finishedAt.timeIntervalSince1970
            }
            if let summary = task.resultSummary, !summary.isEmpty {
                dict["result_summary"] = summary
            }
            if let error = task.errorDescription, !error.isEmpty {
                dict["error"] = error
            }
            return dict
        }

        let result: [String: Any] = [
            "tasks": payload
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"tasks\":[]}"
    }
}

