import Foundation
import MagicKit

/// GitHub 关闭 Issue 工具
struct GitHubCloseIssueTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔒"
    nonisolated static let verbose = false

    let name = "github_close_issue"
    let description = "关闭指定的 GitHub Issue。"

    var inputSchema: [String: Any] {
        [
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
                    "type": "number",
                    "description": "Issue 编号"
                ]
            ],
            "required": ["owner", "repo", "issueNumber"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String,
              let issueNumber = arguments["issueNumber"]?.value as? Int else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner, repo, issueNumber"]
            )
        }

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)关闭 Issue：\(owner)/\(repo)#\(issueNumber)")
        }

        do {
            let issue = try await GitHubAPIService.shared.closeIssue(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber
            )
            return formatClosedIssue(issue)
        } catch {
            GitHubToolsPlugin.logger.error("关闭 Issue 失败：\(error.localizedDescription)")
            return "关闭 Issue 失败：\(error.localizedDescription)"
        }
    }

    private func formatClosedIssue(_ issue: GitHubIssue) -> String {
        return """
        🔒 **Issue 已关闭**

        **#\(issue.number) \(issue.title)**

        **链接**: \(issue.htmlUrl)
        """
    }
}
