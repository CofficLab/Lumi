import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub Issue 评论列表工具
public struct GitHubIssueCommentsTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose: Bool = false
    public static let info = LumiAgentToolInfo(
        id: "github_issue_comments",
        displayName: "GitHubIssueComments",
        description: "GitHub tool: github_issue_comments"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "查看 Issue 评论"    }
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

        let page = Self.normalizedPage(arguments["page"]?.anyValue)
        let perPage = Self.normalizedPerPage(arguments["perPage"]?.anyValue)

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(self.t)获取 Issue 评论：\(owner)/\(repo)#\(issueNumber)")
            }
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
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)获取 Issue 评论失败：\(error.localizedDescription)")
            }
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

    static func normalizedPage(_ value: Any?) -> Int {
        GitHubToolArgumentNormalizer.page(value)
    }

    static func normalizedPerPage(_ value: Any?) -> Int {
        GitHubToolArgumentNormalizer.perPage(value)
    }
}
