import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub 趋势项目工具
public struct GitHubTrendingTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🔥"
    public nonisolated static let verbose: Bool = false
    static let minLimit = 1
    static let defaultLimit = 10
    static let maxLimit = 100
    public let name = "github_trending"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取 GitHub 趋势项目列表，按时间范围（daily/weekly/monthly）筛选热门开源项目。"
        case .english:
            return "Get GitHub trending repositories. Supports time ranges such as daily, weekly, and monthly."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let sinceDesc: String
        let limitDesc: String
        switch language {
        case .chinese:
            sinceDesc = "时间范围：daily、weekly、monthly"
            limitDesc = "返回数量限制，默认 10"
        case .english:
            sinceDesc = "Time range: daily, weekly, monthly"
            limitDesc = "Maximum number of results, default 10"
        }
        return [
            "type": "object",
            "properties": [
                "since": [
                    "type": "string",
                    "description": sinceDesc,
                    "enum": ["daily", "weekly", "monthly"]
                ],
                "limit": [
                    "type": "integer",
                    "description": limitDesc,
                    "minimum": Self.minLimit,
                    "maximum": Self.maxLimit
                ]
            ]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "查看 GitHub 趋势"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let since = Self.normalizedSince(arguments["since"]?.value as? String)
        let limit = Self.normalizedLimit(arguments["limit"]?.value)

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(Self.t)获取趋势项目：since=\(since)")
            }
        }

        do {
            let repos = try await GitHubAPIService.shared.getTrendingRepositories(since: since)
            return formatTrendingRepos(Array(repos.prefix(limit)))
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(Self.t)获取趋势项目失败：\(error.localizedDescription)")
            }
            return "获取趋势项目失败：\(error.localizedDescription)"
        }
    }

    private func formatTrendingRepos(_ repos: [GitHubRepository]) -> String {
        guard !repos.isEmpty else {
            return "暂无趋势项目"
        }

        var output = "🔥 GitHub 趋势项目\n\n"

        for (index, repo) in repos.enumerated() {
            output += """
            \(index + 1). **\(repo.fullName)**
               \(repo.description ?? "无描述")
               ⭐ \(repo.stargazersCount) | 💻 \(repo.language ?? "未知")

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

    static func normalizedSince(_ rawSince: String?) -> String {
        let since = rawSince?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "daily"
        return ["daily", "weekly", "monthly"].contains(since) ? since : "daily"
    }
}
