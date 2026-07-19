import Foundation
import LumiKernel

/// 纯逻辑的「项目问题相关性打分器」，与单例存储解耦，便于单元测试。
///
/// 给定一组未解决问题和用户消息，按严重程度 + 词法命中率打分，
/// 返回最多 `maxResults` 条最相关的问题（同分按更新时间倒序）。
enum IssueRelevanceRanker {
    /// 默认返回的问题数量上限。
    static let defaultMaxResults = 5

    static func pickRelevantIssues(
        issues: [ProjectIssue],
        message: String,
        maxResults: Int = defaultMaxResults
    ) -> [ProjectIssue] {
        let messageTokens = Set(tokenize(message))

        let scored = issues.map { issue in
            var score = severityScore(issue.severity)

            let issuePathTokens = Set(tokenize(issue.filePath))
            let issueTextTokens = Set(tokenize([issue.title, issue.description, issue.suggestion ?? ""].joined(separator: " ")))
            score += messageTokens.intersection(issuePathTokens).count * 3
            score += messageTokens.intersection(issueTextTokens).count

            if issue.source == .llmAnalysis {
                score += 1
            }

            return (issue: issue, score: score)
        }

        return scored
            .sorted(by: { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.issue.updatedAt > rhs.issue.updatedAt
                }
                return lhs.score > rhs.score
            })
            .prefix(maxResults)
            .map(\.issue)
    }

    static func severityScore(_ severity: ProjectIssueSeverity) -> Int {
        switch severity {
        case .critical: return 6
        case .warning: return 4
        case .info: return 2
        }
    }

    /// 简单分词：按非字母数字字符切分、转小写、过滤短词（<3 字符）。
    static func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }
    }
}

/// 在用户发送消息时，将未解决的项目问题注入 system prompt。
struct IssueHintChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = context.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = context.messages.last(where: { $0.role == .user })?.content ?? ""

        let issues = projectPath.isEmpty
            ? await ProjectIssueStore.shared.fetchOpen()
            : await ProjectIssueStore.shared.fetchOpen(projectPath: projectPath)

        guard !issues.isEmpty else {
            return updated
        }

        let relevantIssues = IssueRelevanceRanker.pickRelevantIssues(
            issues: issues,
            message: message
        )

        updated.systemPromptFragments.append(buildPrompt(from: relevantIssues))
        return updated
    }

    private func buildPrompt(from issues: [ProjectIssue]) -> String {
        var lines = ["以下是你可能在处理此项目时需要注意的已知问题（仅供参考，不要主动提及除非用户提问相关内容）："]

        for issue in issues {
            let location = issue.lineNumber.map { ":\($0)" } ?? ""
            let severity = issue.severity.rawValue
            lines.append("- [\(severity)] \(issue.filePath)\(location) — \(issue.title)")
        }

        return lines.joined(separator: "\n")
    }
}
