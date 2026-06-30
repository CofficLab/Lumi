import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub 搜索工具
public struct GitHubSearchTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false
    static let minLimit = 1
    static let defaultLimit = 5
    static let maxLimit = 100
    public static let info = LumiAgentToolInfo(
        id: "github_search",
        displayName: "GitHubSearch",
        description: "GitHub tool: github_search"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "搜索 GitHub"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let query = arguments["query"]?.anyValue as? String else {
            throw NSError(
                domain: Self.info.id,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：query"]
            )
        }

        let language = arguments["language"]?.anyValue as? String
        let minStars = GitHubToolArgumentNormalizer.nonNegativeInteger(arguments["minStars"]?.anyValue)
        let limit = Self.normalizedLimit(arguments["limit"]?.anyValue)

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
