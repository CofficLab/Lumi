import Foundation

struct ListBackgroundTasksTool: AgentTool {
    let name: String = "list_background_agent_tasks"
    let description: String = String(localized: "List recent background agent tasks and their status. Useful for understanding what tasks are running or have completed.", table: "BackgroundAgentTask")

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": String(localized: "Maximum number of tasks to return.", table: "BackgroundAgentTask"),
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

        let tasks = await BackgroundAgentTaskStore.shared.fetchRecent(limit: limit)

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

