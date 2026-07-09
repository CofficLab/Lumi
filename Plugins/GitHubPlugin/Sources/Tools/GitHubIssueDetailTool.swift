import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub Issue 详情工具
public struct GitHubIssueDetailTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true
    public static let info = LumiAgentToolInfo(
        id: "github_issue_detail",
        displayName: "GitHubIssueDetail",
        description: "GitHub tool: github_issue_detail"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "查看 Issue 详情"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.anyValue as? String,
              let repo = arguments["repo"]?.anyValue as? String,
              let issueNumber = GitHubToolArgumentNormalizer.issueNumber(arguments["issueNumber"]?.anyValue) else {
            throw NSError(
                domain: Self.info.id,
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
