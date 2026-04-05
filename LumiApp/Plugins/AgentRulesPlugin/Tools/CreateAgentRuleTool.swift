import Foundation

/// 创建 Agent 规则文档工具
///
/// 在指定项目的 .agent/rules 目录中创建新的规则文档
struct CreateAgentRuleTool: AgentTool {
    let name: String = "create_agent_rule"
    let description: String = String(localized: "Create a new rule document in the .agent/rules directory of a project. The document will be created as a Markdown file with the specified title and content.", table: "AgentRules")

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": String(localized: "Absolute path to the project directory containing .agent/rules folder.", table: "AgentRules")
                ],
                "filename": [
                    "type": "string",
                    "description": String(localized: "The filename for the new rule document (without .md extension, will be added automatically). Use kebab-case or snake_case naming convention.", table: "AgentRules")
                ],
                "title": [
                    "type": "string",
                    "description": String(localized: "The title of the rule document (will be added as a level 1 heading).", table: "AgentRules")
                ],
                "content": [
                    "type": "string",
                    "description": String(localized: "The content of the rule document in Markdown format. If empty, only the title heading will be created.", table: "AgentRules")
                ]
            ],
            "required": ["project_path", "filename", "title"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        // 文件创建操作需要中等权限
        .medium
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let projectPath = arguments["project_path"]?.value as? String, !projectPath.isEmpty else {
            throw AgentRulesError.invalidFileFormat("project_path is required")
        }

        guard let filename = arguments["filename"]?.value as? String, !filename.isEmpty else {
            throw AgentRulesError.invalidFileFormat("Filename is required")
        }

        guard let title = arguments["title"]?.value as? String, !title.isEmpty else {
            throw AgentRulesError.invalidFileFormat("Title is required")
        }

        let content = arguments["content"]?.value as? String ?? ""

        // 创建规则文档
        let rule = try await AgentRulesService.shared.createRule(
            projectPath: projectPath,
            filename: filename,
            title: title,
            content: content
        )

        // 返回创建的规则信息
        let result: [String: Any] = [
            "success": true,
            "message": "Rule document created successfully",
            "rule": [
                "id": rule.id,
                "filename": rule.filename,
                "title": rule.title,
                "description": rule.description,
                "file_size": rule.fileSize,
                "created_at": rule.createdAt.timeIntervalSince1970,
                "file_path": rule.filePath
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"success\":false}"
    }
}
