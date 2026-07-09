import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub 趋势项目工具
public struct GitHubTrendingTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔥"
    public nonisolated static let verbose: Bool = true
    static let minLimit = 1
    static let defaultLimit = 10
    static let maxLimit = 100
    public static let info = LumiAgentToolInfo(
        id: "github_trending",
        displayName: "GitHubTrending",
        description: "GitHub tool: github_trending"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "查看 GitHub 趋势"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let since = Self.normalizedSince(arguments["since"]?.anyValue as? String)
        let limit = Self.normalizedLimit(arguments["limit"]?.anyValue)

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
