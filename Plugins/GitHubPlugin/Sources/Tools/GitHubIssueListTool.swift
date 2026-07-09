import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub Issue 列表工具
public struct GitHubIssueListTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true
    public static let info = LumiAgentToolInfo(
        id: "github_issues",
        displayName: "GitHubIssues",
        description: "GitHub tool: github_issues"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "列出 Issue"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.anyValue as? String,
              let repo = arguments["repo"]?.anyValue as? String else {
            throw NSError(
                domain: Self.info.id,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner 和 repo"]
            )
        }

        let stateRaw = arguments["state"]?.anyValue as? String ?? "open"
        let state = GitHubIssueState(rawValue: stateRaw) ?? .open
        let page = Self.normalizedPage(arguments["page"]?.anyValue)
        let perPage = Self.normalizedPerPage(arguments["perPage"]?.anyValue)

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(Self.t)获取 Issue 列表：\(owner)/\(repo) state=\(stateRaw)")
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
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(Self.t)获取 Issue 列表失败：\(error.localizedDescription)")
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
