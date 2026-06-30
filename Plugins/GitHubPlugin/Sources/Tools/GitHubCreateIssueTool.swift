import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub 创建 Issue 工具
public struct GitHubCreateIssueTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "✍️"
    public nonisolated static let verbose: Bool = false
    public static let info = LumiAgentToolInfo(
        id: "github_create_issue",
        displayName: "GitHubCreateIssue",
        description: "GitHub tool: github_create_issue"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "创建 Issue"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.anyValue as? String,
              let repo = arguments["repo"]?.anyValue as? String,
              let title = arguments["title"]?.anyValue as? String else {
            throw NSError(
                domain: Self.info.id,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner, repo, title"]
            )
        }

        let body = arguments["body"]?.anyValue as? String
        let labels = arguments["labels"]?.anyValue as? [String]
        let assignees = arguments["assignees"]?.anyValue as? [String]
        let milestone = GitHubToolArgumentNormalizer.issueNumber(arguments["milestone"]?.anyValue)

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(Self.t)创建 Issue：\(owner)/\(repo) - \(title)")
            }
        }

        do {
            let issue = try await GitHubAPIService.shared.createIssue(
                owner: owner,
                repo: repo,
                title: title,
                body: body,
                labels: labels,
                assignees: assignees,
                milestone: milestone
            )
            return formatCreatedIssue(issue)
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(Self.t)创建 Issue 失败：\(error.localizedDescription)")
            }
            return "创建 Issue 失败：\(error.localizedDescription)"
        }
    }

    private func formatCreatedIssue(_ issue: GitHubIssue) -> String {
        let stateEmoji = issue.state == .open ? "🟢" : "🔴"

        return """
        \(stateEmoji) **Issue 已创建**

        **#\(issue.number) \(issue.title)**

        \(issue.body ?? "")

        **链接**: \(issue.htmlUrl)
        """
    }
}
