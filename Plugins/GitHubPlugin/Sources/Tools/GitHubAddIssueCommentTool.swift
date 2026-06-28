import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub 添加 Issue 评论工具
public struct GitHubAddIssueCommentTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose: Bool = false
    public let name = "github_add_issue_comment"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "在 GitHub Issue 中添加评论，支持 Markdown 格式。"
        case .english:
            return "Add a comment to a GitHub issue. Markdown is supported."
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
                    ],
                    "body": [
                        "type": "string",
                        "description": "评论内容（支持 Markdown 格式）"
                    ]
                ],
                "required": ["owner", "repo", "issueNumber", "body"]
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
                    ],
                    "body": [
                        "type": "string",
                        "description": "Comment body (Markdown supported)"
                    ]
                ],
                "required": ["owner", "repo", "issueNumber", "body"]
            ]
        }
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "添加 Issue 评论"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String,
              let issueNumber = GitHubToolArgumentNormalizer.issueNumber(arguments["issueNumber"]?.value),
              let body = arguments["body"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner, repo, issueNumber, body"]
            )
        }

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(self.t)添加 Issue 评论：\(owner)/\(repo)#\(issueNumber)")
            }
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
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)添加评论失败：\(error.localizedDescription)")
            }
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
