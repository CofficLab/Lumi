import Foundation

@MainActor
final class GitHubKBMiddleware: SuperSendMiddleware {
    let id = "github-insight-kb"
    let order = 60

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let message = ctx.message.content
        guard shouldInject(for: message) else {
            await next(ctx)
            return
        }

        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            await next(ctx)
            return
        }

        let entries = await GitHubInsightKnowledgeBaseManager.shared.loadEntries(projectPath: projectPath)
        let relevant = filter(entries: entries, for: message).prefix(3)
        guard !relevant.isEmpty else {
            await next(ctx)
            return
        }

        ctx.transientSystemPrompts.append(
            buildPrompt(entries: Array(relevant), languagePreference: ctx.projectVM.languagePreference)
        )
        await next(ctx)
    }

    private func shouldInject(for message: String) -> Bool {
        let lowercased = message.lowercased()
        let keywords = [
            "recommend", "alternative", "best practice", "library", "framework", "dependency",
            "推荐", "替代", "最佳实践", "开源", "框架", "依赖", "库", "生态"
        ]
        return keywords.contains { lowercased.contains($0) }
    }

    private func filter(entries: [GitHubInsightKBEntry], for message: String) -> [GitHubInsightKBEntry] {
        let lowercased = message.lowercased()
        let relation: GitHubInsightRelationType?
        if lowercased.contains("alternative") || lowercased.contains("替代") {
            relation = .alternative
        } else if lowercased.contains("example") || lowercased.contains("best practice") || lowercased.contains("最佳实践") || lowercased.contains("示例") {
            relation = .example
        } else {
            relation = nil
        }

        return entries
            .filter { relation == nil || $0.relationType == relation }
            .sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func buildPrompt(entries: [GitHubInsightKBEntry], languagePreference: LanguagePreference) -> String {
        var lines: [String]

        switch languagePreference {
        case .chinese:
            lines = [
                "## GitHub 生态洞察",
                "",
                "以下缓存的 GitHub 生态参考可能相关。请将它们视为需要验证的线索，而不是权威结论。",
                "",
                "| 仓库 | 类型 | 信号 |",
                "|------|------|------|"
            ]
        case .english:
            lines = [
                "## GitHub Ecosystem Insights",
                "",
                "The following cached GitHub ecosystem references may be relevant. Treat them as leads to verify, not as authoritative conclusions.",
                "",
                "| Repo | Type | Signal |",
                "|------|------|--------|"
            ]
        }

        for entry in entries {
            let insight = entry.keyInsights.first ?? entry.description
            lines.append("| `\(entry.fullName)` | \(entry.relationType.title) | \(insight) |")
        }

        lines.append("")
        switch languagePreference {
        case .chinese:
            lines.append("需要更多缓存的仓库详情时，使用 `query_eco_kb`。")
        case .english:
            lines.append("Use `query_eco_kb` for more cached repository details when needed.")
        }
        return lines.joined(separator: "\n")
    }
}
