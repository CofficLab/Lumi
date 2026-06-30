import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub 关闭 Issue 工具
public struct GitHubCloseIssueTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔒"
    public nonisolated static let verbose: Bool = false
    public static let info = LumiAgentToolInfo(
        id: "github_close_issue",
        displayName: "GitHubCloseIssue",
        description: "GitHub tool: github_close_issue"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "关闭 Issue"    }
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
                            GitHubPlugin.logger.info("\(self.t)关闭 Issue：\(owner)/\(repo)#\(issueNumber)")
            }
        }

        do {
            let issue = try await GitHubAPIService.shared.closeIssue(
                owner: owner,
                repo: repo,
                issueNumber: issueNumber
            )
            return formatClosedIssue(issue)
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)关闭 Issue 失败：\(error.localizedDescription)")
            }
            return "关闭 Issue 失败：\(error.localizedDescription)"
        }
    }

    private func formatClosedIssue(_ issue: GitHubIssue) -> String {
        return """
        🔒 **Issue 已关闭**

        **#\(issue.number) \(issue.title)**

        **链接**: \(issue.htmlUrl)
        """
    }
}
