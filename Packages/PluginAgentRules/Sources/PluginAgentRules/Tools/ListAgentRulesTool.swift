import KitAgentTool
import Foundation

/// 列出 Agent 规则文档工具
///
/// 返回指定项目 .agent/rules 目录中所有规则文档的列表。
/// 由旧版 `LumiAgentTool` 迁移为 `SuperAgentTool`；`kernel.currentProjectPath`
/// 改为 `AgentRulesRuntime.currentProjectPath`。
public struct ListAgentRulesTool: SuperAgentTool {
    static let minLimit = 0
    static let maxLimit = 100

    public let name = "list_agent_rules"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List all rule documents in the .agent/rules directory of a project. Returns metadata including filename, title, description, file size, and modification date for each rule document."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": "Absolute path to the project directory containing .agent/rules folder.",
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of rules to return (default: all).",
                    "minimum": Self.minLimit,
                    "maximum": Self.maxLimit,
                ],
            ],
            "required": [],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "列出规则" }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
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

        let limitValue = Self.normalizedLimit(arguments["limit"]?.value)
        var rules = try await AgentRulesService.shared.listRules(projectPath: projectPath)

        if let limit = limitValue {
            guard limit > 0 else {
                rules = []
                return try encodedRulesPayload(for: rules)
            }
            rules = Array(rules.prefix(limit))
        }

        return try encodedRulesPayload(for: rules)
    }

    static func normalizedLimit(_ value: Any?) -> Int? {
        let raw: Int?
        if let int = value as? Int {
            raw = int
        } else if let double = value as? Double {
            raw = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            raw = int
        } else {
            raw = nil
        }

        guard let raw else { return nil }
        return min(max(raw, Self.minLimit), Self.maxLimit)
    }

    private func encodedRulesPayload(for rules: [AgentRuleMetadata]) throws -> String {
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
