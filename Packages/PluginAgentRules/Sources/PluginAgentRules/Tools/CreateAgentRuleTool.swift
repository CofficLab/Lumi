import KitAgentTool
import Foundation

/// 创建 Agent 规则文档工具
///
/// 在指定项目的 .agent/rules 目录中创建新的规则文档。
/// 由旧版 `LumiAgentTool` 迁移为 `SuperAgentTool`；`kernel.currentProjectPath`
/// 改为 `AgentRulesRuntime.currentProjectPath`。
public struct CreateAgentRuleTool: SuperAgentTool {
    public let name = "create_agent_rule"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create a new rule document in the .agent/rules directory of a project. The document will be created as a Markdown file with the specified title and content."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": "Absolute path to the project directory containing .agent/rules folder.",
                ],
                "filename": [
                    "type": "string",
                    "description": "The filename for the new rule document (without .md extension, will be added automatically). Use kebab-case or snake_case naming convention.",
                ],
                "title": [
                    "type": "string",
                    "description": "The title of the rule document (will be added as a level 1 heading).",
                ],
                "content": [
                    "type": "string",
                    "description": "The content of the rule document in Markdown format. If empty, only the title heading will be created.",
                ],
            ],
            "required": ["filename", "title"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "创建规则" }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        // 优先使用显式参数，fallback 到当前项目。
        let explicitPath = (arguments["project_path"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPath: String? = await MainActor.run { AgentRulesRuntime.currentProjectPath }
        let projectPath = explicitPath ?? currentPath

        guard let projectPath, !projectPath.isEmpty else {
            throw AgentRulesError.invalidFileFormat("project_path is required (no current project selected)")
        }

        guard let filename = arguments["filename"]?.value as? String, !filename.isEmpty else {
            throw AgentRulesError.invalidFileFormat("Filename is required")
        }

        guard let title = arguments["title"]?.value as? String, !title.isEmpty else {
            throw AgentRulesError.invalidFileFormat("Title is required")
        }

        let content = arguments["content"]?.value as? String ?? ""

        let rule = try await AgentRulesService.shared.createRule(
            projectPath: projectPath,
            filename: filename,
            title: title,
            content: content
        )

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
