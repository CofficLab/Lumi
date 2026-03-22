import Foundation
import MagicKit

/// GitHub Issue 列表工具
struct GitHubIssueListTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    let name = "github_issues"
    let description = "获取 GitHub 仓库的 Issue 列表，支持按状态（open/closed/all）筛选。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "owner": [
                    "type": "string",
                    "description": "仓库所有者（用户名或组织名）"
                ],
                "repo": [
                    "type": "string",
                    "description": "仓库名称"
                ],
                "state": [
                    "type": "string",
                    "description": "Issue 状态：open（开放）、closed（已关闭）、all（全部），默认 open",
                    "enum": ["open", "closed", "all"]
                ],
                "page": [
                    "type": "number",
                    "description": "页码，默认 1"
                ],
                "perPage": [
                    "type": "number",
                    "description": "每页数量，默认 10，最大 100"
                ]
            ],
            "required": ["owner", "repo"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner 和 repo"]
            )
        }

        let stateRaw = arguments["state"]?.value as? String ?? "open"
        let state = GitHubIssueState(rawValue: stateRaw) ?? .open
        let page = arguments["page"]?.value as? Int ?? 1
        let perPage = min(arguments["perPage"]?.value as? Int ?? 10, 100)

        if Self.verbose {
            GitHubToolsPlugin.logger.info("\(Self.t)获取 Issue 列表：\(owner)/\(repo) state=\(stateRaw)")
        }

        do {
            let issues = try await GitHubAPIService.shared.getIssues(
                owner: owner,
                repo: repo,
                state: state,
                page: page,
                perPage: perPage
            )
            return formatIssues(issues)
        } catch {
            GitHubToolsPlugin.logger.error("\(Self.t)获取 Issue 列表失败：\(error.localizedDescription)")
            return "获取 Issue 列表失败：\(error.localizedDescription)"
        }
    }

    private func formatIssues(_ issues: [GitHubIssue]) -> String {
        guard !issues.isEmpty else {
            return "暂无 Issue"
        }

        var output = "📋 GitHub Issue 列表\n\n"

        for (index, issue) in issues.enumerated() {
            let stateEmoji = issue.state == .open ? "🟢" : "🔴"
            let labelsText = issue.labels.isEmpty ? "" : " | 标签：\(issue.labels.map { $0.name }.joined(separator: ", "))"
            let milestoneText = issue.milestone != nil ? " | 里程碑：\(issue.milestone!.title)" : ""

            output += """
            \(index + 1). \(stateEmoji) **#\((issue.number)) \(issue.title)**
               作者：\(issue.user.login) | 评论：\(issue.comments) | 更新于：\(formatDate(issue.updatedAt))\(labelsText)\(milestoneText)
               \(issue.htmlUrl)

            """
        }

        return output
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "zh_CN")

        if let date = formatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }
        return dateString.prefix(10).description
    }
}
