import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub 重新打开 Issue 工具
public struct GitHubReopenIssueTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔓"
    public nonisolated static let verbose: Bool = false
    public static let info = LumiAgentToolInfo(
        id: "github_reopen_issue",
        displayName: "GitHubReopenIssue",
        description: "GitHub tool: github_reopen_issue"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "重新打开 Issue"    }
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

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(self.t)重新打开 Issue：\(owner)/\(repo)#\(issueNumber)")
            }
        }

        do {
            let issue = try await GitHubAPIService.shared.reopenIssue(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber
            )
            return formatReopenedIssue(issue)
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)重新打开 Issue 失败：\(error.localizedDescription)")
            }
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
