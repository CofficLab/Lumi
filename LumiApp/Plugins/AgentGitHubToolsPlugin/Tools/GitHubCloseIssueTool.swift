import Foundation
import ToolKit
import GitHubKit

/// GitHub 关闭 Issue 工具
struct GitHubCloseIssueTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔒"
    nonisolated static let verbose: Bool = false
    let name = "github_close_issue"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "关闭指定的 GitHub Issue。"
        case .english:
            return "Close the specified GitHub issue."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
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
                        "type": "number",
                        "description": "Issue 编号"
                    ]
                ],
                "required": ["owner", "repo", "issueNumber"]
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
                        "type": "number",
                        "description": "Issue number"
                    ]
                ],
                "required": ["owner", "repo", "issueNumber"]
            ]
        }
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
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

        if Self.verbose {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.info("\(self.t)关闭 Issue：\(owner)/\(repo)#\(issueNumber)")
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
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.error("关闭 Issue 失败：\(error.localizedDescription)")
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
