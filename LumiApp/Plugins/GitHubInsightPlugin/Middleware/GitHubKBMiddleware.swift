import Foundation
import ToolKit

/// 将相关的缓存 GitHub 生态参考注入到外发聊天上下文中。
///
/// 中间件仅在推荐、依赖、框架或生态相关提示中启用。它会读取当前项目的
/// 本地知识库，并追加包含最相关缓存条目的临时系统提示。
@MainActor
final class GitHubKBMiddleware: SuperSendMiddleware {
    /// 发送流水线使用的稳定中间件标识。
    let id = "github-insight-kb"

    /// 中间件在发送流水线中的执行顺序。
    let order = 60

    /// 处理外发消息，并在相关时追加 GitHub 生态上下文。
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

    /// 判断消息是否看起来需要生态或依赖建议。
    private func shouldInject(for message: String) -> Bool {
        let lowercased = message.lowercased()
        let keywords = [
            "recommend", "alternative", "best practice", "library", "framework", "dependency",
            "推荐", "替代", "最佳实践", "开源", "框架", "依赖", "库", "生态"
        ]
        return keywords.contains { lowercased.contains($0) }
    }

    /// 按相关性排序缓存条目。
    private func filter(entries: [GitHubInsightKBEntry], for message: String) -> [GitHubInsightKBEntry] {
        return entries
            .sorted { $0.relevanceScore > $1.relevanceScore }
    }

    /// 构建用于概括缓存生态参考的临时系统提示。
    private func buildPrompt(entries: [GitHubInsightKBEntry], languagePreference: LanguagePreference) -> String {
        var lines: [String]

        switch languagePreference {
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
        switch languagePreference {
        case .chinese:
            lines.append("需要更多缓存的仓库详情时，使用 `query_eco_kb`。")
        case .english:
            lines.append("Use `query_eco_kb` for more cached repository details when needed.")
        }
        return lines.joined(separator: "\n")
    }
}
