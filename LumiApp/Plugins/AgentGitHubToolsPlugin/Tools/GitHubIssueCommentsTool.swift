import Foundation
import MagicKit

/// GitHub Issue 评论列表工具
struct GitHubIssueCommentsTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = false
    let name = "github_issue_comments"
    let description = "获取 GitHub Issue 的评论列表。"

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
                "page": [
                    "type": "number",
                    "description": "页码，默认 1"
                ],
                "perPage": [
                    "type": "number",
                    "description": "每页数量，默认 10，最大 100"
                ]
            ],
            "required": ["owner", "repo", "issueNumber"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
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

        let page = arguments["page"]?.value as? Int ?? 1
        let perPage = min(arguments["perPage"]?.value as? Int ?? 10, 100)

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)获取 Issue 评论：\(owner)/\(repo)#\(issueNumber)")
        }

        do {
            let comments = try await GitHubAPIService.shared.getIssueComments(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber,
                page: page,
                perPage: perPage
            )
            return formatComments(comments)
        } catch {
            GitHubToolsPlugin.logger.error("\(self.t)获取 Issue 评论失败：\(error.localizedDescription)")
            return "获取 Issue 评论失败：\(error.localizedDescription)"
        }
    }

    private func formatComments(_ comments: [GitHubIssueComment]) -> String {
        guard !comments.isEmpty else {
            return "暂无评论"
        }

        var output = "💬 Issue 评论（\(comments.count) 条）\n\n"

        for (index, comment) in comments.enumerated() {
            output += """
            \(index + 1). **@\(comment.user.login)** - \(formatDate(comment.updatedAt))
               \(comment.body.prefix(200))\(comment.body.count > 200 ? "..." : "")

            """
        }

        return output
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
