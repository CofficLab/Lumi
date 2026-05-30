import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub 创建 Issue 工具
public struct GitHubCreateIssueTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "✍️"
    public nonisolated static let verbose: Bool = true
    public let name = "github_create_issue"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "在 GitHub 仓库中创建新的 Issue。支持设置标题、描述、标签、指派人员和里程碑。"
        case .english:
            return "Create a new issue in a GitHub repository. Supports title, body, labels, assignees, and milestone."
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
                    "title": [
                        "type": "string",
                        "description": "Issue 标题"
                    ],
                    "body": [
                        "type": "string",
                        "description": "Issue 描述（支持 Markdown 格式）"
                    ],
                    "labels": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "标签名称数组，如 [\"bug\", \"help wanted\"]"
                    ],
                    "assignees": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "指派的用户名数组"
                    ],
                    "milestone": [
                        "type": "number",
                        "description": "里程碑编号"
                    ]
                ],
                "required": ["owner", "repo", "title"]
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
                    "title": [
                        "type": "string",
                        "description": "Issue title"
                    ],
                    "body": [
                        "type": "string",
                        "description": "Issue description (Markdown supported)"
                    ],
                    "labels": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Array of label names, e.g. [\"bug\", \"help wanted\"]"
                    ],
                    "assignees": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Array of usernames to assign"
                    ],
                    "milestone": [
                        "type": "number",
                        "description": "Milestone number"
                    ]
                ],
                "required": ["owner", "repo", "title"]
            ]
        }
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "创建 Issue"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String,
              let title = arguments["title"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner, repo, title"]
            )
        }

        let body = arguments["body"]?.value as? String
        let labels = arguments["labels"]?.value as? [String]
        let assignees = arguments["assignees"]?.value as? [String]
        let milestone = arguments["milestone"]?.value as? Int

        if Self.verbose {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.info("\(Self.t)创建 Issue：\(owner)/\(repo) - \(title)")
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
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.error("\(Self.t)创建 Issue 失败：\(error.localizedDescription)")
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
