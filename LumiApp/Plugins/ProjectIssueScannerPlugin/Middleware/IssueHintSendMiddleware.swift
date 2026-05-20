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
        let issues = await ProjectIssueStore.shared.fetchOpen()

        guard !issues.isEmpty else {
            await next(ctx)
            return
        }

        // TODO: 实现智能匹配 — 根据用户消息内容筛选相关问题
        // 当前策略：取最近的 Top N 个未解决问题
        let relevantIssues = Array(issues.prefix(5))

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
}
