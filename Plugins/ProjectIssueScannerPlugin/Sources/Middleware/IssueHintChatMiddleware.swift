import Foundation
import LumiCoreKit

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

        let relevantIssues = pickRelevantIssues(
            issues: issues,
            message: message,
            projectPath: projectPath
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

    private func pickRelevantIssues(
        issues: [ProjectIssue],
        message: String,
        projectPath: String
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
            .prefix(5)
            .map(\.issue)
    }

    private func severityScore(_ severity: ProjectIssueSeverity) -> Int {
        switch severity {
        case .critical: return 6
        case .warning: return 4
        case .info: return 2
        }
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }
    }
}
