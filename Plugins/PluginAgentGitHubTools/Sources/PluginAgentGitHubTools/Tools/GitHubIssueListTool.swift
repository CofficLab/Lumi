import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub Issue 列表工具
public struct GitHubIssueListTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true
    public let name = "github_issues"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取 GitHub 仓库的 Issue 列表，支持按状态（open/closed/all）筛选。"
        case .english:
            return "List issues in a GitHub repository. Supports filtering by state: open, closed, or all."
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
                        "type": "integer",
                        "description": "页码，默认 1",
                        "minimum": 1
                    ],
                    "perPage": [
                        "type": "integer",
                        "description": "每页数量，默认 10，范围 1-100",
                        "minimum": 1,
                        "maximum": 100
                    ]
                ],
                "required": ["owner", "repo"]
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
                    "state": [
                        "type": "string",
                        "description": "Issue state: open, closed, or all. Default: open",
                        "enum": ["open", "closed", "all"]
                    ],
                    "page": [
                        "type": "integer",
                        "description": "Page number, default 1",
                        "minimum": 1
                    ],
                    "perPage": [
                        "type": "integer",
                        "description": "Results per page, default 10, range 1-100",
                        "minimum": 1,
                        "maximum": 100
                    ]
                ],
                "required": ["owner", "repo"]
            ]
        }
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "列出 Issue"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
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
        let page = Self.normalizedPage(arguments["page"]?.value)
        let perPage = Self.normalizedPerPage(arguments["perPage"]?.value)

        if Self.verbose {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.info("\(Self.t)获取 Issue 列表：\(owner)/\(repo) state=\(stateRaw)")
            }
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
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.error("\(Self.t)获取 Issue 列表失败：\(error.localizedDescription)")
            }
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

    static func normalizedPage(_ value: Any?) -> Int {
        GitHubToolArgumentNormalizer.page(value)
    }

    static func normalizedPerPage(_ value: Any?) -> Int {
        GitHubToolArgumentNormalizer.perPage(value)
    }
}
