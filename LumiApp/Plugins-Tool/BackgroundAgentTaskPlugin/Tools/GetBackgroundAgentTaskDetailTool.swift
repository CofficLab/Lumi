import Foundation

struct GetBackgroundAgentTaskDetailTool: AgentTool {
    let name: String = "get_background_agent_task_detail"
    let description: String = "根据任务 ID 查询单个后台 Agent 任务的详细信息，包括指令、状态、结果摘要与错误信息。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "task_id": [
                    "type": "string",
                    "description": "后台任务的 UUID 字符串。"
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
                userInfo: [NSLocalizedDescriptionKey: "task_id 必须是有效的 UUID 字符串"]
            )
        }

        guard let task = BackgroundAgentTaskStore.shared.fetchById(uuid) else {
            let result: [String: Any] = [
                "found": false,
                "task_id": idString,
                "message": "指定 ID 的后台任务不存在"
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

