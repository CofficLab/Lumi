import Foundation
import MagicKit
import OSLog

/// GitHub 创建 Issue 工具
struct GitHubCreateIssueTool: AgentTool, SuperLog {
    nonisolated static let emoji = "✍️"
    nonisolated static let verbose = false

    let name = "github_create_issue"
    let description = "在 GitHub 仓库中创建新的 Issue。支持设置标题、描述、标签、指派人员和里程碑。"

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
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
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
            os_log("\(Self.t)✍️ 创建 Issue：\(owner)/\(repo) - \(title)")
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
            os_log(.error, "\(Self.t)创建 Issue 失败：\(error.localizedDescription)")
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
