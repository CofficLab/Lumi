import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub 搜索工具
public struct GitHubSearchTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false
    static let minLimit = 1
    static let defaultLimit = 5
    static let maxLimit = 100
    public let name = "github_search"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "在 GitHub 上搜索仓库和代码。支持关键词、语言、stars 等条件筛选。"
        case .english:
            return "Search repositories and code on GitHub. Supports filters such as keywords, language, and stars."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
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
                    "type": "integer",
                    "description": minStarsDesc,
                    "minimum": 0
                ],
                "limit": [
                    "type": "integer",
                    "description": limitDesc,
                    "minimum": Self.minLimit,
                    "maximum": Self.maxLimit
                ]
            ],
            "required": ["query"]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "搜索 GitHub"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let query = arguments["query"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：query"]
            )
        }

        let language = arguments["language"]?.value as? String
        let minStars = GitHubToolArgumentNormalizer.nonNegativeInteger(arguments["minStars"]?.value)
        let limit = Self.normalizedLimit(arguments["limit"]?.value)

        // 构建搜索查询
        var searchQuery = query
        if let language = language {
            searchQuery += " language:\(language)"
        }
        if minStars > 0 {
            searchQuery += " stars:>=\(minStars)"
        }

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(Self.t)搜索：\(searchQuery)")
            }
        }

        do {
            let result = try await GitHubAPIService.shared.searchRepositories(
                query: searchQuery,
                perPage: limit
            )
            return Self.formatSearchResult(result)
        } catch {
            return "搜索失败：\(error.localizedDescription)"
        }
    }

    static func formatSearchResult(_ result: GitHubSearchResult) -> String {
        guard !result.items.isEmpty else {
            return "未找到匹配的仓库"
        }

        var output = "🔍 找到 \(result.totalCount) 个结果，显示前 \(result.items.count) 个：\n\n"

        for (index, repo) in result.items.enumerated() {
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

    static func normalizedLimit(_ value: Any?) -> Int {
        let rawLimit: Int?
        if let int = value as? Int {
            rawLimit = int
        } else if let double = value as? Double {
            rawLimit = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            rawLimit = int
        } else {
            rawLimit = nil
        }

        return min(max(rawLimit ?? defaultLimit, minLimit), maxLimit)
    }
}
