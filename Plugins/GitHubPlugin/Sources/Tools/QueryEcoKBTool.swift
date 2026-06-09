import Foundation
import AgentToolKit

/// 用于搜索本地 GitHub 生态知识库的 Agent 工具。
///
/// 该工具会对缓存仓库条目执行离线搜索，并返回匹配的相关 GitHub 仓库。
public struct QueryEcoKBTool: SuperAgentTool {
    static let defaultResultLimit = 5
    static let maxResultLimit = 20

    /// 暴露给 Agent 的工具名称。
    public let name = "query_eco_kb"

    /// 返回展示给 Agent 的本地化工具描述。
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查询本地缓存的 GitHub 生态知识库，获取与当前项目相关的仓库。"
        case .english:
            return "Query the local cached GitHub ecosystem knowledge base for repositories related to the current project."
        }
    }

    /// 定义工具接受的 JSON schema。
    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Search keyword, dependency, framework, or repository name."
                ],
                "project_path": [
                    "type": "string",
                    "description": "Optional project path. If omitted, all cached project knowledge bases are searched."
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of entries to return. Default 5, range: 1-20.",
                    "minimum": 1,
                    "maximum": Self.maxResultLimit
                ]
            ],
            "required": ["query"]
        ]
    }

    /// 声明该工具为低风险，因为它只读取本地缓存数据。
    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "查询生态知识库"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 对项目专属或全局缓存条目执行关键词搜索。
    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let query = (arguments["query"]?.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return String(localized: "Missing required parameter: query", bundle: .module)
        }

        let limit = Self.normalizedLimit(arguments["limit"]?.value)
        let projectPath = (arguments["project_path"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let entries: [GitHubInsightKBEntry]
        if let projectPath, !projectPath.isEmpty {
            entries = await GitHubInsightKnowledgeBaseManager.shared.loadEntries(projectPath: projectPath)
        } else {
            entries = await GitHubInsightKnowledgeBaseManager.shared.loadAllEntries()
        }

        let tokens = query.lowercased().split(separator: " ").map(String.init)
        let matches = entries
            .filter { entry in
                let haystack = ([entry.fullName, entry.description, entry.language ?? ""] + entry.topics + entry.keyInsights).joined(separator: " ").lowercased()
                return tokens.allSatisfy { haystack.contains($0) }
            }
            .sorted { lhs, rhs in
                if lhs.relevanceScore != rhs.relevanceScore { return lhs.relevanceScore > rhs.relevanceScore }
                return lhs.stars > rhs.stars
            }
            .prefix(limit)

        guard !matches.isEmpty else {
            return String(format: String(localized: "No cached GitHub ecosystem entries matched `%@`.", bundle: .module), query)
        }

        var lines = ["## GitHub Ecosystem KB Results", ""]
        for entry in matches {
            lines.append("### \(entry.fullName)")
            lines.append("- Stars: \(entry.stars)")
            lines.append("- Language: \(entry.language ?? "Unknown")")
            lines.append("- URL: \(entry.repoURL)")
            if !entry.description.isEmpty {
                lines.append("- Description: \(entry.description)")
            }
            if !entry.keyInsights.isEmpty {
                lines.append("- Signals: \(entry.keyInsights.joined(separator: " "))")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func normalizedLimit(_ value: Any?) -> Int {
        let requested: Int
        if let int = value as? Int {
            requested = int
        } else if let double = value as? Double {
            requested = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            requested = int
        } else {
            requested = defaultResultLimit
        }

        return min(max(requested, 1), maxResultLimit)
    }
}
