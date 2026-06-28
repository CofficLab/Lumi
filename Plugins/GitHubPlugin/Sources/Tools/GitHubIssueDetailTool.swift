import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub Issue 详情工具
public struct GitHubIssueDetailTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = false
    public let name = "github_issue_detail"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取 GitHub Issue 的详细信息，包括标题、描述、状态、标签、评论数等。"
        case .english:
            return "Get detailed information for a GitHub issue, including title, body, state, labels, comment count, and more."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let ownerDesc: String
        let repoDesc: String
        let issueNumberDesc: String
        switch language {
        case .chinese:
            ownerDesc = "仓库所有者"
            repoDesc = "仓库名称"
            issueNumberDesc = "Issue 编号（如 123）"
        case .english:
            ownerDesc = "Repository owner"
            repoDesc = "Repository name"
            issueNumberDesc = "Issue number (e.g., 123)"
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
                ],
                "issueNumber": [
                    "type": "integer",
                    "description": issueNumberDesc,
                    "minimum": GitHubToolArgumentNormalizer.minIssueNumber
                ]
            ],
            "required": ["owner", "repo", "issueNumber"]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "查看 Issue 详情"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
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
                            GitHubPlugin.logger.info("\(self.t)获取 Issue 详情：\(owner)/\(repo)#\(issueNumber)")
            }
        }

        do {
            let issue = try await GitHubAPIService.shared.getIssue(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber
            )
            return formatIssueDetail(issue)
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)获取 Issue 详情失败：\(error.localizedDescription)")
            }
            return "获取 Issue 详情失败：\(error.localizedDescription)"
        }
    }

    private func formatIssueDetail(_ issue: GitHubIssue) -> String {
        let stateEmoji = issue.state == .open ? "🟢" : "🔴"
        let stateText = issue.state == .open ? "开放中" : "已关闭"

        var output = """
        \(stateEmoji) Issue #\(issue.number) - \(issue.title)

        **状态**: \(stateText)
        **作者**: \(issue.user.login)
        **创建时间**: \(formatDate(issue.createdAt))
        **更新时间**: \(formatDate(issue.updatedAt))
        **评论**: \(issue.comments) 条

        """

        if let body = issue.body, !body.isEmpty {
            output += """
            ---
            \(body)

            """
        }

        if !issue.labels.isEmpty {
            let labelsText = issue.labels.map { label in
                if !label.color.isEmpty {
                    return " `#\(label.name)`"
                }
                return " `#\(label.name)`"
            }.joined()
            output += "**标签**:\(labelsText)\n\n"
        }

        if let milestone = issue.milestone {
            output += "**里程碑**: \(milestone.title)\n\n"
        }

        output += "**链接**: \(issue.htmlUrl)"

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
