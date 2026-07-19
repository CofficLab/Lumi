import Foundation
import LumiKernel

/// 创建 Agent 规则文档工具
///
/// 在指定项目的 .agent/rules 目录中创建新的规则文档
public struct CreateAgentRuleTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "create_agent_rule",
        displayName: LumiPluginLocalization.string("Create Agent Rule", bundle: .module),
        description: "Create a new rule document in the .agent/rules directory of a project. The document will be created as a Markdown file with the specified title and content."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the project directory containing .agent/rules folder.")
                ]),
                "filename": .object([
                    "type": .string("string"),
                    "description": .string("The filename for the new rule document (without .md extension, will be added automatically). Use kebab-case or snake_case naming convention.")
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("The title of the rule document (will be added as a level 1 heading).")
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("The content of the rule document in Markdown format. If empty, only the title heading will be created.")
                ])
            ]),
            "required": .array([.string("project_path"), .string("filename"), .string("title")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "创建规则" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .medium }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let projectPath = arguments.string("project_path"), !projectPath.isEmpty else {
            throw AgentRulesError.invalidFileFormat("project_path is required")
        }

        guard let filename = arguments.string("filename"), !filename.isEmpty else {
            throw AgentRulesError.invalidFileFormat("Filename is required")
        }

        guard let title = arguments.string("title"), !title.isEmpty else {
            throw AgentRulesError.invalidFileFormat("Title is required")
        }

        let content = arguments.string("content") ?? ""

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
