import Foundation
import LumiCoreKit

/// 列出 Agent 规则文档工具
///
/// 返回指定项目 .agent/rules 目录中所有规则文档的列表
public struct ListAgentRulesTool: LumiAgentTool {
    static let minLimit = 0
    static let maxLimit = 100

    public static let info = LumiAgentToolInfo(
        id: "list_agent_rules",
        displayName: LumiPluginLocalization.string("List Agent Rules", bundle: .module),
        description: "List all rule documents in the .agent/rules directory of a project. Returns metadata including filename, title, description, file size, and modification date for each rule document."
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
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of rules to return (default: all)."),
                    "minimum": .int(Self.minLimit),
                    "maximum": .int(Self.maxLimit)
                ])
            ]),
            "required": .array([.string("project_path")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "列出规则" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let projectPath = arguments.string("project_path"), !projectPath.isEmpty else {
            throw AgentRulesError.invalidFileFormat("project_path is required")
        }

        let limitValue = Self.normalizedLimit(arguments["limit"]?.anyValue)
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
