import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub 更新 Issue 工具
public struct GitHubUpdateIssueTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "✏️"
    public nonisolated static let verbose: Bool = true
    public static let info = LumiAgentToolInfo(
        id: "github_update_issue",
        displayName: "GitHubUpdateIssue",
        description: "GitHub tool: github_update_issue"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "更新 Issue"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
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

        let title = arguments["title"]?.anyValue as? String
        let body = arguments["body"]?.anyValue as? String
        let state = arguments["state"]?.anyValue as? String
        let labels = arguments["labels"]?.anyValue as? [String]
        let assignees = arguments["assignees"]?.anyValue as? [String]
        let milestone = GitHubToolArgumentNormalizer.issueNumber(arguments["milestone"]?.anyValue)

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(self.t)更新 Issue：\(owner)/\(repo)#\(issueNumber)")
            }
        }

        do {
            let issue = try await GitHubAPIService.shared.updateIssue(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber,
                title: title,
                body: body,
                state: state,
                labels: labels,
                assignees: assignees,
                milestone: milestone
            )
            return formatUpdatedIssue(issue)
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)更新 Issue 失败：\(error.localizedDescription)")
            }
            return "更新 Issue 失败：\(error.localizedDescription)"
        }
    }

    private func formatUpdatedIssue(_ issue: GitHubIssue) -> String {
        let stateEmoji = issue.state == .open ? "🟢" : "🔴"
        let stateText = issue.state == .open ? "开放中" : "已关闭"

        return """
        \(stateEmoji) **Issue 已更新**

        **#\(issue.number) \(issue.title)**

        **状态**: \(stateText)
        **链接**: \(issue.htmlUrl)
        """
    }
}
