import Foundation

/// 问题提示注入中间件
///
/// 在用户发送消息时，读取 IssueStore 中未解决的问题，
/// 按相关性筛选后注入到 transientSystemPrompts，供 LLM 参考。
@MainActor
struct IssueHintSendMiddleware: SuperSendMiddleware {
    let id: String = "project-issue-scanner.hint"
    let order: Int = 9_900

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let issues = projectPath.isEmpty
            ? await ProjectIssueStore.shared.fetchOpen()
            : await ProjectIssueStore.shared.fetchOpen(projectPath: projectPath)

        guard !issues.isEmpty else {
            await next(ctx)
            return
        }

        let relevantIssues = pickRelevantIssues(
            issues: issues,
            message: ctx.message.content,
            currentFileURL: ctx.currentFileURL,
            projectPath: projectPath
        )

        let prompt = buildPrompt(from: relevantIssues)
        ctx.transientSystemPrompts.append(prompt)

        await next(ctx)
    }

    // MARK: - Private

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
        currentFileURL: URL?,
        projectPath: String
    ) -> [ProjectIssue] {
        let messageTokens = Set(tokenize(message))
        let currentRelativePath = currentFileURL.map { url in
            relativePath(for: url, projectPath: projectPath)
        }

        let scored = issues.map { issue in
            var score = severityScore(issue.severity)

            if let currentRelativePath, issue.filePath == currentRelativePath {
                score += 8
            }

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

    private func relativePath(for fileURL: URL, projectPath: String) -> String {
        let rootPath = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return filePath }

        let start = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        return String(filePath[start...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
