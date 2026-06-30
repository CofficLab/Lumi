import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub 添加 Issue 评论工具
public struct GitHubAddIssueCommentTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose: Bool = false
    public static let info = LumiAgentToolInfo(
        id: "github_add_issue_comment",
        displayName: "GitHubAddIssueComment",
        description: "GitHub tool: github_add_issue_comment"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "添加 Issue 评论"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.anyValue as? String,
              let repo = arguments["repo"]?.anyValue as? String,
              let issueNumber = GitHubToolArgumentNormalizer.issueNumber(arguments["issueNumber"]?.anyValue),
              let body = arguments["body"]?.anyValue as? String else {
            throw NSError(
                domain: Self.info.id,
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
