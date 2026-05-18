import Foundation
import MagicKit

struct QueryEcoKBTool: SuperAgentTool {
    let name = "query_eco_kb"

    func description(for language: LanguagePreference) -> String {
        String(localized: "Query the local cached GitHub ecosystem knowledge base for related repositories, alternatives, examples, and ecosystem tools.", table: "GitHubInsight")
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
            return String(localized: "Missing required parameter: query", table: "GitHubInsight")
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
            return String(format: String(localized: "No cached GitHub ecosystem entries matched `%@`.", table: "GitHubInsight"), query)
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
