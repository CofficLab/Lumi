import Foundation
import GitHubKit
import LumiKernel
import SuperLogKit

/// GitHub 仓库信息工具
public struct GitHubRepoInfoTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📦"
    public nonisolated static let verbose: Bool = true
    public static let info = LumiAgentToolInfo(
        id: "github_repo_info",
        displayName: "GitHubRepoInfo",
        description: "GitHub tool: github_repo_info"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "查看仓库信息"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.anyValue as? String,
              let repo = arguments["repo"]?.anyValue as? String else {
            throw NSError(
                domain: Self.info.id,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner 和 repo"]
            )
        }

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(self.t)获取仓库信息：\(owner)/\(repo)")
            }
        }

        do {
            let repoInfo = try await GitHubAPIService.shared.getRepoInfo(
                owner: owner,
                repo: repo
            )
            return formatRepoInfo(repoInfo)
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)获取仓库信息失败：\(error.localizedDescription)")
            }
            return "获取仓库信息失败：\(error.localizedDescription)"
        }
    }

    private func formatRepoInfo(_ repo: GitHubRepository) -> String {
        """
        📦 \(repo.fullName)

        \(repo.description ?? "无描述")

        ⭐ Stars: \(repo.stargazersCount)
        🍴 Forks: \(repo.forksCount)
        📌 Open Issues: \(repo.openIssuesCount ?? 0)
        💻 Language: \(repo.language ?? "未知")
        🔗 URL: \(repo.htmlUrl)
        """
    }
}
