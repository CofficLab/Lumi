import Foundation
import LumiCoreKit

/// 用于搜索本地 GitHub 生态知识库的 Agent 工具。
///
/// 该工具会对缓存仓库条目执行离线搜索，并返回匹配的相关 GitHub 仓库。
public struct QueryEcoKBTool: LumiAgentTool {
    static let defaultResultLimit = 5
    static let maxResultLimit = 20

    /// 暴露给 Agent 的工具名称。
    public static let info = LumiAgentToolInfo(
        id: "query_eco_kb",
        displayName: "QueryEcoKb",
        description: "GitHub tool: query_eco_kb"
    )

    /// 返回展示给 Agent 的本地化工具描述。

    /// 定义工具接受的 JSON schema。
    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    /// 声明该工具为低风险，因为它只读取本地缓存数据。
    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "查询生态知识库"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    /// 对项目专属或全局缓存条目执行关键词搜索。
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let query = (arguments["query"]?.anyValue as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return LumiPluginLocalization.string("Missing required parameter: query", bundle: .module)
        }

        let limit = Self.normalizedLimit(arguments["limit"]?.anyValue)
        let projectPath = (arguments["project_path"]?.anyValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

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
            return String(format: LumiPluginLocalization.string("No cached GitHub ecosystem entries matched `%@`.", bundle: .module), query)
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
