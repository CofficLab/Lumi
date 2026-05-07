import Foundation
import MagicKit

/// GitHub 更新 Issue 工具
struct GitHubUpdateIssueTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false
    let name = "github_update_issue"
    let description = "更新 GitHub Issue 的信息，包括标题、描述、状态、标签、指派人员和里程碑。"

    var inputSchema: [String: Any] {
        [
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
                    "type": "number",
                    "description": "里程碑编号（可选，null 表示移除）"
                ]
            ],
            "required": ["owner", "repo", "issueNumber"]
        ]
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

        let title = arguments["title"]?.value as? String
        let body = arguments["body"]?.value as? String
        let state = arguments["state"]?.value as? String
        let labels = arguments["labels"]?.value as? [String]
        let assignees = arguments["assignees"]?.value as? [String]
        let milestone = arguments["milestone"]?.value as? Int

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)更新 Issue：\(owner)/\(repo)#\(issueNumber)")
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
            GitHubToolsPlugin.logger.error("更新 Issue 失败：\(error.localizedDescription)")
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
