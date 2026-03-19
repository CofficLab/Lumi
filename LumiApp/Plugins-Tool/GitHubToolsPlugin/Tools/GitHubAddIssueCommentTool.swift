import Foundation
import MagicKit

/// GitHub 添加 Issue 评论工具
struct GitHubAddIssueCommentTool: AgentTool, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    let name = "github_add_issue_comment"
    let description = "在 GitHub Issue 中添加评论，支持 Markdown 格式。"

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
                ],
                "body": [
                    "type": "string",
                    "description": "评论内容（支持 Markdown 格式）"
                ]
            ],
            "required": ["owner", "repo", "issueNumber", "body"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String,
              let issueNumber = arguments["issueNumber"]?.value as? Int,
              let body = arguments["body"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner, repo, issueNumber, body"]
            )
        }

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)添加 Issue 评论：\(owner)/\(repo)#\(issueNumber)")
        }

        do {
            let comment = try await GitHubAPIService.shared.addIssueComment(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber,
                body: body
            )
            return formatAddedComment(comment)
        } catch {
            GitHubToolsPlugin.logger.error("添加评论失败：\(error.localizedDescription)")
            return "添加评论失败：\(error.localizedDescription)"
        }
    }

    private func formatAddedComment(_ comment: GitHubIssueComment) -> String {
        return """
        💬 **评论已添加**

        @\(comment.user.login) - \(formatDate(comment.createdAt))

        \(comment.body)

        **链接**: \(comment.htmlUrl)
        """
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "zh_CN")

        if let date = formatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }
        return dateString.prefix(10).description
    }
}
