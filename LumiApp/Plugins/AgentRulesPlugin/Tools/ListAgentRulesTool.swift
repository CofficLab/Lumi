import Foundation

/// 列出 Agent 规则文档工具
///
/// 返回指定项目 .agent/rules 目录中所有规则文档的列表
struct ListAgentRulesTool: SuperAgentTool {
    let name: String = "list_agent_rules"
    let description: String = String(localized: "List all rule documents in the .agent/rules directory of a project. Returns metadata including filename, title, description, file size, and modification date for each rule document.", table: "AgentRules")

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": String(localized: "Absolute path to the project directory containing .agent/rules folder.", table: "AgentRules")
                ],
                "limit": [
                    "type": "integer",
                    "description": String(localized: "Maximum number of rules to return (default: all).", table: "AgentRules"),
                    "minimum": 1
                ]
            ],
            "required": ["project_path"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let projectPath = arguments["project_path"]?.value as? String, !projectPath.isEmpty else {
            throw AgentRulesError.invalidFileFormat("project_path is required")
        }

        let limitValue = arguments["limit"]?.value as? Int
        var rules = try await AgentRulesService.shared.listRules(projectPath: projectPath)

        // 应用限制
        if let limit = limitValue, limit > 0 {
            rules = Array(rules.prefix(limit))
        }

        // 转换为 JSON 格式
        let payload: [[String: Any]] = rules.map { rule in
            [
                "id": rule.id,
                "filename": rule.filename,
                "title": rule.title,
                "description": rule.description,
                "file_size": rule.fileSize,
                "formatted_file_size": rule.formattedFileSize,
                "modified_at": rule.modifiedAt.timeIntervalSince1970,
                "formatted_modified_date": rule.formattedModifiedDate,
                "file_path": rule.filePath
            ]
        }

        let result: [String: Any] = [
            "count": rules.count,
            "rules": payload
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"count\":0,\"rules\":[]}"
    }
}
