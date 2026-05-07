import Foundation
import MagicKit

/// GitHub 搜索工具
struct GitHubSearchTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false
    let name = "github_search"
    let description = "在 GitHub 上搜索仓库和代码。支持关键词、语言、stars 等条件筛选。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "搜索关键词"
                ],
                "language": [
                    "type": "string",
                    "description": "编程语言过滤（可选）"
                ],
                "minStars": [
                    "type": "number",
                    "description": "最小 star 数（可选）"
                ],
                "limit": [
                    "type": "number",
                    "description": "返回结果数量限制，默认 5"
                ]
            ],
            "required": ["query"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
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
            GitHubToolsPlugin.logger.info("\(Self.t)搜索：\(searchQuery)")
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
