import Foundation
import MagicKit

/// GitHub 趋势项目工具
struct GitHubTrendingTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔥"
    nonisolated static let verbose: Bool = false
    let name = "github_trending"
    let description = "获取 GitHub 趋势项目列表，按时间范围（daily/weekly/monthly）筛选热门开源项目。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "since": [
                    "type": "string",
                    "description": "时间范围：daily、weekly、monthly",
                    "enum": ["daily", "weekly", "monthly"]
                ],
                "limit": [
                    "type": "number",
                    "description": "返回数量限制，默认 10"
                ]
            ]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let since = arguments["since"]?.value as? String ?? "daily"
        let limit = arguments["limit"]?.value as? Int ?? 10

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(Self.t)获取趋势项目：since=\(since)")
        }

        do {
            let repos = try await GitHubAPIService.shared.getTrendingRepositories(since: since)
            return formatTrendingRepos(Array(repos.prefix(limit)))
        } catch {
            GitHubToolsPlugin.logger.error("\(Self.t)获取趋势项目失败：\(error.localizedDescription)")
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
}
