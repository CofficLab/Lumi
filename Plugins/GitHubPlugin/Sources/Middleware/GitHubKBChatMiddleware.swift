import Foundation
import LumiKernel

/// 将相关的缓存 GitHub 生态参考注入到外发聊天上下文中。
struct GitHubKBChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let message = context.messages.last(where: { $0.role == .user })?.content ?? ""
        guard shouldInject(for: message) else {
            return updated
        }

        let projectPath = context.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            return updated
        }

        let entries = await GitHubInsightKnowledgeBaseManager.shared.loadEntries(projectPath: projectPath)
        let relevant = filter(entries: entries, for: message).prefix(3)
        guard !relevant.isEmpty else {
            return updated
        }

        updated.systemPromptFragments.append(
            buildPrompt(entries: Array(relevant), language: context.conversationLanguage)
        )
        return updated
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
        entries.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func buildPrompt(entries: [GitHubInsightKBEntry], language: LumiConversationLanguage) -> String {
        var lines: [String]

        switch language {
        case .chinese:
            lines = [
                "## GitHub 生态洞察",
                "",
                "以下缓存的 GitHub 生态参考可能相关。请将它们视为需要验证的线索，而不是权威结论。",
                "",
                "| 仓库 | 信号 |",
                "|------|------|"
            ]
        case .english:
            lines = [
                "## GitHub Ecosystem Insights",
                "",
                "The following cached GitHub ecosystem references may be relevant. Treat them as leads to verify, not as authoritative conclusions.",
                "",
                "| Repo | Signal |",
                "|------|--------|"
            ]
        }

        for entry in entries {
            let insight = entry.keyInsights.first ?? entry.description
            lines.append("| `\(entry.fullName)` | \(insight) |")
        }

        lines.append("")
        switch language {
        case .chinese:
            lines.append("需要更多缓存的仓库详情时，使用 `query_eco_kb`。")
        case .english:
            lines.append("Use `query_eco_kb` for more cached repository details when needed.")
        }
        return lines.joined(separator: "\n")
    }
}
