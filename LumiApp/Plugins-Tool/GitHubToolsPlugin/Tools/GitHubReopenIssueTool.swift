import Foundation
import MagicKit

/// GitHub 重新打开 Issue 工具
struct GitHubReopenIssueTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔓"
    nonisolated static let verbose = false

    let name = "github_reopen_issue"
    let description = "重新打开已关闭的 GitHub Issue。"

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
            GitHubToolsPlugin.logger.info("\(self.t)重新打开 Issue：\(owner)/\(repo)#\(issueNumber)")
        }

        do {
            let issue = try await GitHubAPIService.shared.reopenIssue(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber
            )
            return formatReopenedIssue(issue)
        } catch {
            GitHubToolsPlugin.logger.error("重新打开 Issue 失败：\(error.localizedDescription)")
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
