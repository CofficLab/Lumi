import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub 重新打开 Issue 工具
public struct GitHubReopenIssueTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🔓"
    public nonisolated static let verbose: Bool = false
    public let name = "github_reopen_issue"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "重新打开已关闭的 GitHub Issue。"
        case .english:
            return "Reopen a closed GitHub issue."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        switch language {
        case .chinese:
            return [
                "type": "object",
                "properties": [
                    "owner": [
                        "type": "string",
                        "description": "仓库所有者"
                    ],
                    "repo": [
                        "type": "string",
                        "description": "仓库名称"
                    ],
                    "issueNumber": [
                        "type": "integer",
                        "description": "Issue 编号",
                        "minimum": GitHubToolArgumentNormalizer.minIssueNumber
                    ]
                ],
                "required": ["owner", "repo", "issueNumber"]
            ]
        case .english:
            return [
                "type": "object",
                "properties": [
                    "owner": [
                        "type": "string",
                        "description": "Repository owner"
                    ],
                    "repo": [
                        "type": "string",
                        "description": "Repository name"
                    ],
                    "issueNumber": [
                        "type": "integer",
                        "description": "Issue number",
                        "minimum": GitHubToolArgumentNormalizer.minIssueNumber
                    ]
                ],
                "required": ["owner", "repo", "issueNumber"]
            ]
        }
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "重新打开 Issue"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String,
              let issueNumber = GitHubToolArgumentNormalizer.issueNumber(arguments["issueNumber"]?.value) else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner, repo, issueNumber"]
            )
        }

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(self.t)重新打开 Issue：\(owner)/\(repo)#\(issueNumber)")
            }
        }

        do {
            let issue = try await GitHubAPIService.shared.reopenIssue(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber
            )
            return formatReopenedIssue(issue)
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)重新打开 Issue 失败：\(error.localizedDescription)")
            }
            return "重新打开 Issue 失败：\(error.localizedDescription)"
        }
    }

    private func formatReopenedIssue(_ issue: GitHubIssue) -> String {
        return """
        🔓 **Issue 已重新打开**

        **#\(issue.number) \(issue.title)**

        **链接**: \(issue.htmlUrl)
        """
    }
}
