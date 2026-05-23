import Foundation
import AgentToolKit
import GitHubKit

/// GitHub 搜索工具
struct GitHubSearchTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false
    let name = "github_search"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "在 GitHub 上搜索仓库和代码。支持关键词、语言、stars 等条件筛选。"
        case .english:
            return "Search repositories and code on GitHub. Supports filters such as keywords, language, and stars."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let queryDesc: String
        let languageDesc: String
        let minStarsDesc: String
        let limitDesc: String
        switch language {
        case .chinese:
            queryDesc = "搜索关键词"
            languageDesc = "编程语言过滤（可选）"
            minStarsDesc = "最小 star 数（可选）"
            limitDesc = "返回结果数量限制，默认 5"
        case .english:
            queryDesc = "Search query keyword"
            languageDesc = "Programming language filter (optional)"
            minStarsDesc = "Minimum number of stars (optional)"
            limitDesc = "Maximum number of results, default 5"
        }
        return [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": queryDesc
                ],
                "language": [
                    "type": "string",
                    "description": languageDesc
                ],
                "minStars": [
                    "type": "number",
                    "description": minStarsDesc
                ],
                "limit": [
                    "type": "number",
                    "description": limitDesc
                ]
            ],
            "required": ["query"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let query = arguments["query"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：query"]
            )
        }

        let language = arguments["language"]?.value as? String
        let minStars = arguments["minStars"]?.value as? Int ?? 0
        let limit = arguments["limit"]?.value as? Int ?? 5

        // 构建搜索查询
        var searchQuery = query
        if let language = language {
            searchQuery += " language:\(language)"
        }
        if minStars > 0 {
            searchQuery += " stars:>=\(minStars)"
        }

        if Self.verbose {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.info("\(Self.t)搜索：\(searchQuery)")
            }
        }

        do {
            let result = try await GitHubAPIService.shared.searchRepositories(
                query: searchQuery,
                perPage: limit
            )
            return formatSearchResult(result)
        } catch {
            return "搜索失败：\(error.localizedDescription)"
        }
    }

    private func formatSearchResult(_ result: GitHubSearchResult) -> String {
        guard !result.items.isEmpty else {
            return "未找到匹配的仓库"
        }

        var output = "🔍 找到 \(result.totalCount) 个结果，显示前 \(result.items.count) 个：\n\n"

        for (index, repo) in result.items.enumerated().prefix(5) {
            output += """
            \(index + 1). **\(repo.fullName)**
               \(repo.description ?? "无描述")
               ⭐ \(repo.stargazersCount) | 🍴 \(repo.forksCount)
               💻 \(repo.language ?? "未知")
               🔗 \(repo.htmlUrl)

            """
        }

        return output
    }
}
