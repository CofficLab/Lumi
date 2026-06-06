import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub 仓库信息工具
public struct GitHubRepoInfoTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📦"
    public nonisolated static let verbose: Bool = false
    public let name = "github_repo_info"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取 GitHub 仓库的基本信息，包括 star 数、forks、描述、主要语言等。"
        case .english:
            return "Get basic information for a GitHub repository, including stars, forks, description, primary language, and more."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let ownerDesc: String
        let repoDesc: String
        switch language {
        case .chinese:
            ownerDesc = "仓库所有者（用户名或组织名）"
            repoDesc = "仓库名称"
        case .english:
            ownerDesc = "Repository owner (username or organization)"
            repoDesc = "Repository name"
        }
        return [
            "type": "object",
            "properties": [
                "owner": [
                    "type": "string",
                    "description": ownerDesc
                ],
                "repo": [
                    "type": "string",
                    "description": repoDesc
                ]
            ],
            "required": ["owner", "repo"]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "查看仓库信息"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner 和 repo"]
            )
        }

        if Self.verbose {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.info("\(self.t)获取仓库信息：\(owner)/\(repo)")
            }
        }

        do {
            let repoInfo = try await GitHubAPIService.shared.getRepoInfo(
                owner: owner,
                repo: repo
            )
            return formatRepoInfo(repoInfo)
        } catch {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.error("\(self.t)获取仓库信息失败：\(error.localizedDescription)")
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
