import Foundation
import MagicKit

/// GitHub 仓库信息工具
struct GitHubRepoInfoTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose: Bool = false
    let name = "github_repo_info"
    let description = "获取 GitHub 仓库的基本信息，包括 star 数、forks、描述、主要语言等。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "owner": [
                    "type": "string",
                    "description": "仓库所有者（用户名或组织名）"
                ],
                "repo": [
                    "type": "string",
                    "description": "仓库名称"
                ]
            ],
            "required": ["owner", "repo"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner 和 repo"]
            )
        }

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)获取仓库信息：\(owner)/\(repo)")
        }

        do {
            let repoInfo = try await GitHubAPIService.shared.getRepoInfo(
                owner: owner,
                repo: repo
            )
            return formatRepoInfo(repoInfo)
        } catch {
            GitHubToolsPlugin.logger.error("\(self.t)获取仓库信息失败：\(error.localizedDescription)")
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
