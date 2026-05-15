import Foundation
import MagicKit

struct QueryEcoKBTool: SuperAgentTool {
    let name = "query_eco_kb"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查询本地缓存的 GitHub 生态知识库，获取相关仓库、替代方案、示例和生态工具。"
        case .english:
            return "Query the local cached GitHub ecosystem knowledge base for related repositories, alternatives, examples, and ecosystem tools."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Search keyword, dependency, framework, or repository name."
                ],
                "relation_type": [
                    "type": "string",
                    "enum": ["alternative", "complementary", "example"],
                    "description": "Optional relation filter."
                ],
                "project_path": [
                    "type": "string",
                    "description": "Optional project path. If omitted, all cached project knowledge bases are searched."
                ],
                "limit": [
                    "type": "number",
                    "description": "Maximum number of entries to return. Default 5."
                ]
            ],
            "required": ["query"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let query = (arguments["query"]?.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return "Missing required parameter: query"
        }

        let limit = arguments["limit"]?.value as? Int ?? 5
        let relation = (arguments["relation_type"]?.value as? String).flatMap(GitHubInsightRelationType.init(rawValue:))
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
                if let relation, entry.relationType != relation { return false }
                let haystack = ([entry.fullName, entry.description, entry.language ?? ""] + entry.topics + entry.keyInsights).joined(separator: " ").lowercased()
                return tokens.allSatisfy { haystack.contains($0) }
            }
            .sorted { lhs, rhs in
                if lhs.relevanceScore != rhs.relevanceScore { return lhs.relevanceScore > rhs.relevanceScore }
                return lhs.stars > rhs.stars
            }
            .prefix(max(limit, 1))

        guard !matches.isEmpty else {
            return "No cached GitHub ecosystem entries matched `\(query)`. Sync the GitHub Insight status item first if the project has no cache yet."
        }

        var lines = ["## GitHub Ecosystem KB Results", ""]
        for entry in matches {
            lines.append("### \(entry.fullName)")
            lines.append("- Type: \(entry.relationType.title)")
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
}
