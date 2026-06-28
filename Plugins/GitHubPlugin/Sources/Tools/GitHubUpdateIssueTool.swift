import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub 更新 Issue 工具
public struct GitHubUpdateIssueTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "✏️"
    public nonisolated static let verbose: Bool = false
    public let name = "github_update_issue"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "更新 GitHub Issue 的信息，包括标题、描述、状态、标签、指派人员和里程碑。"
        case .english:
            return "Update a GitHub issue, including title, body, state, labels, assignees, and milestone."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
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
                        "type": "integer",
                        "description": "Issue 编号",
                        "minimum": GitHubToolArgumentNormalizer.minIssueNumber
                    ],
                    "title": [
                        "type": "string",
                        "description": "新的标题（可选）"
                    ],
                    "body": [
                        "type": "string",
                        "description": "新的描述（可选）"
                    ],
                    "state": [
                        "type": "string",
                        "description": "状态：open 或 closed",
                        "enum": ["open", "closed"]
                    ],
                    "labels": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "新的标签数组（可选）"
                    ],
                    "assignees": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "新的指派用户数组（可选）"
                    ],
                    "milestone": [
                        "type": "integer",
                        "description": "里程碑编号（可选，null 表示移除）",
                        "minimum": 1
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
                        "description": "Repository owner (username or organization)"
                    ],
                    "repo": [
                        "type": "string",
                        "description": "Repository name"
                    ],
                    "issueNumber": [
                        "type": "integer",
                        "description": "Issue number",
                        "minimum": GitHubToolArgumentNormalizer.minIssueNumber
                    ],
                    "title": [
                        "type": "string",
                        "description": "New title (optional)"
                    ],
                    "body": [
                        "type": "string",
                        "description": "New description (optional)"
                    ],
                    "state": [
                        "type": "string",
                        "description": "State: open or closed",
                        "enum": ["open", "closed"]
                    ],
                    "labels": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "New labels array (optional)"
                    ],
                    "assignees": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "New assignees array (optional)"
                    ],
                    "milestone": [
                        "type": "integer",
                        "description": "Milestone number (optional, null to remove)",
                        "minimum": 1
                    ]
                ],
                "required": ["owner", "repo", "issueNumber"]
            ]
        }
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "更新 Issue"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
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

        let title = arguments["title"]?.value as? String
        let body = arguments["body"]?.value as? String
        let state = arguments["state"]?.value as? String
        let labels = arguments["labels"]?.value as? [String]
        let assignees = arguments["assignees"]?.value as? [String]
        let milestone = GitHubToolArgumentNormalizer.issueNumber(arguments["milestone"]?.value)

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
