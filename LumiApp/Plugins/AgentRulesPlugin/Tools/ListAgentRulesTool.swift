import Foundation

/// 列出 Agent 规则文档工具
///
/// 返回 .agent/rules 目录中所有规则文档的列表
struct ListAgentRulesTool: AgentTool {
    let name: String = "list_agent_rules"
    let description: String = String(localized: "List all rule documents in the .agent/rules directory. Returns metadata including filename, title, description, file size, and modification date for each rule document.", table: "AgentRules")

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": String(localized: "Maximum number of rules to return (default: all).", table: "AgentRules"),
                    "minimum": 1
                ]
            ]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let limitValue = arguments["limit"]?.value as? Int
        var rules = try await AgentRulesService.shared.listRules()

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
