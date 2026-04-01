import Foundation

struct GetBackgroundTaskDetailTool: AgentTool {
    let name: String = "get_background_agent_task_detail"
    let description: String = String(localized: "Get detailed information about a background agent task by ID, including instruction, status, result summary, and error message.", table: "BackgroundAgentTask")

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "task_id": [
                    "type": "string",
                    "description": String(localized: "Task ID of the background agent task.", table: "BackgroundAgentTask")
                ]
            ],
            "required": ["task_id"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let idString = arguments["task_id"]?.value as? String,
              let uuid = UUID(uuidString: idString) else {
            throw NSError(
                domain: "GetBackgroundAgentTaskDetailTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "task_id must be a valid UUID string", table: "BackgroundAgentTask")]
            )
        }

        guard let task = BackgroundAgentTaskStore.shared.fetchById(uuid) else {
            let result: [String: Any] = [
                "found": false,
                "task_id": idString,
                "message": String(localized: "Background task with specified ID does not exist", table: "BackgroundAgentTask")
            ]
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
            return String(data: data, encoding: .utf8) ?? "{\"found\":false}"
        }

        var detail: [String: Any] = [
            "found": true,
            "task_id": task.id.uuidString,
            "status": BackgroundAgentTaskStatus(rawOrDefault: task.statusRawValue).rawValue,
            "original_prompt": task.originalPrompt,
            "created_at": task.createdAt.timeIntervalSince1970
        ]

        if let startedAt = task.startedAt {
            detail["started_at"] = startedAt.timeIntervalSince1970
        }
        if let finishedAt = task.finishedAt {
            detail["finished_at"] = finishedAt.timeIntervalSince1970
        }
        if let summary = task.resultSummary, !summary.isEmpty {
            detail["result_summary"] = summary
        }
        if let error = task.errorDescription, !error.isEmpty {
            detail["error"] = error
        }

        let data = try JSONSerialization.data(withJSONObject: detail, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"found\":true}"
    }
}

