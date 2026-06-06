import AgentToolKit
import Foundation
import LumiCoreKit
import MemoryKit
import SuperLogKit

/// 记忆注入中间件。
@MainActor
final class MemoryContextSuperSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "🧠"
    nonisolated static let verbose: Bool = false
    let id: String = "memory-context"
    let order: Int = 5

    // MARK: - 执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let config = MemoryPlugin.config
        let projectPath = config.projectPathProvider(ctx).trimmingCharacters(in: .whitespacesAndNewlines)
        let maxRelevant = config.maxRelevantMemories
        let injectGlobal = config.injectGlobalIndex
        let injectProject = config.injectProjectIndex

        let lang = config.languagePreferenceProvider(ctx)

        var globalIndex = ""
        var projectIndex = ""
        var globalRelevant: [MemoryItem] = []
        var projectRelevant: [MemoryItem] = []

        if injectGlobal {
            globalIndex = await MemoryStorageService.shared.readIndex(scope: .global)
            let userMessage = ctx.message.content
            globalRelevant = await MemoryRetrievalService.shared.findRelevant(
                query: userMessage,
                scope: .global,
                maxResults: maxRelevant
            )
        }

        if !projectPath.isEmpty && injectProject {
            let projectScope: MemoryScope = .project(projectPath)
            projectIndex = await MemoryStorageService.shared.readIndex(scope: projectScope)
            let userMessage = ctx.message.content
            projectRelevant = await MemoryRetrievalService.shared.findRelevant(
                query: userMessage,
                scope: projectScope,
                maxResults: maxRelevant
            )
        }

        let hasAnyMemory = !globalIndex.isEmpty || !projectIndex.isEmpty

        guard hasAnyMemory else {
            if Self.verbose || MemoryPlugin.verbose {
                MemoryPlugin.logger.info("\(Self.t)   ⏭️ 跳过 (无记忆)")
            }
            await next(ctx)
            return
        }

        let staleThreshold = config.staleThresholdDays
        let prompt = buildMemoryPrompt(
            globalIndex: globalIndex,
            projectIndex: projectIndex,
            globalRelevant: globalRelevant,
            projectRelevant: projectRelevant,
            languagePreference: lang,
            staleThresholdDays: staleThreshold
        )

        if !prompt.isEmpty {
            ctx.transientSystemPrompts.append(prompt)

            if Self.verbose || MemoryPlugin.verbose {
                let totalRelevant = globalRelevant.count + projectRelevant.count
                MemoryPlugin.logger.info("\(Self.t)   ✅ 已注入记忆提示词 (\(totalRelevant) 条相关记忆)")
            }
        }

        await next(ctx)
    }

    // MARK: - 提示词构建

    private func buildMemoryPrompt(
        globalIndex: String,
        projectIndex: String,
        globalRelevant: [MemoryItem],
        projectRelevant: [MemoryItem],
        languagePreference: LanguagePreference,
        staleThresholdDays: Int
    ) -> String {
        switch languagePreference {
        case .chinese:
            return buildChinesePrompt(
                globalIndex: globalIndex,
                projectIndex: projectIndex,
                globalRelevant: globalRelevant,
                projectRelevant: projectRelevant,
                staleThresholdDays: staleThresholdDays
            )
        case .english:
            return buildEnglishPrompt(
                globalIndex: globalIndex,
                projectIndex: projectIndex,
                globalRelevant: globalRelevant,
                projectRelevant: projectRelevant,
                staleThresholdDays: staleThresholdDays
            )
        }
    }

    private func buildChinesePrompt(
        globalIndex: String,
        projectIndex: String,
        globalRelevant: [MemoryItem],
        projectRelevant: [MemoryItem],
        staleThresholdDays: Int
    ) -> String {
        var lines: [String] = []
        lines.append("## 记忆系统")
        lines.append("")
        lines.append("你有一个持久化的文件记忆系统。你可以使用 `save_memory`、`recall_memory`、`list_memories` 和 `delete_memory` 工具来管理记忆。")
        lines.append("")

        if !globalIndex.isEmpty {
            lines.append("### 全局记忆索引")
            lines.append("")
            let content = globalIndex.components(separatedBy: .newlines).filter { !$0.hasPrefix("# ") }.joined(separator: "\n")
            lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        if !projectIndex.isEmpty {
            lines.append("### 项目记忆索引")
            lines.append("")
            let content = projectIndex.components(separatedBy: .newlines).filter { !$0.hasPrefix("# ") }.joined(separator: "\n")
            lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        let allRelevant = globalRelevant + projectRelevant
        if !allRelevant.isEmpty {
            lines.append("### 相关记忆（本次对话特别相关）")
            lines.append("")
            for memory in allRelevant {
                lines.append(memory.formattedContent(staleThresholdDays: staleThresholdDays))
                lines.append("")
            }
        }

        lines.append("### 记忆使用规则")
        lines.append("- 记忆是时间点快照，不是实时状态。如果记忆与当前代码冲突，以代码为准。")
        lines.append("- 如果用户让你「记住」什么，使用 save_memory 工具保存。")
        lines.append("- 如果用户让你「忘记」什么，使用 delete_memory 工具删除。")
        lines.append("- 不要主动提及「根据记忆」——自然地运用即可。")

        return lines.joined(separator: "\n")
    }

    private func buildEnglishPrompt(
        globalIndex: String,
        projectIndex: String,
        globalRelevant: [MemoryItem],
        projectRelevant: [MemoryItem],
        staleThresholdDays: Int
    ) -> String {
        var lines: [String] = []
        lines.append("## Memory System")
        lines.append("")
        lines.append("You have a persistent file-based memory system. You can use `save_memory`, `recall_memory`, `list_memories`, and `delete_memory` tools to manage memories.")
        lines.append("")

        if !globalIndex.isEmpty {
            lines.append("### Global Memory Index")
            lines.append("")
            let content = globalIndex.components(separatedBy: .newlines).filter { !$0.hasPrefix("# ") }.joined(separator: "\n")
            lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        if !projectIndex.isEmpty {
            lines.append("### Project Memory Index")
            lines.append("")
            let content = projectIndex.components(separatedBy: .newlines).filter { !$0.hasPrefix("# ") }.joined(separator: "\n")
            lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        let allRelevant = globalRelevant + projectRelevant
        if !allRelevant.isEmpty {
            lines.append("### Relevant Memories (particularly relevant to this conversation)")
            lines.append("")
            for memory in allRelevant {
                lines.append(memory.formattedContent(staleThresholdDays: staleThresholdDays))
                lines.append("")
            }
        }

        lines.append("### Memory Usage Rules")
        lines.append("- Memories are point-in-time snapshots, not live state. If a memory conflicts with current code, trust the code.")
        lines.append("- If the user asks you to \"remember\" something, use the save_memory tool.")
        lines.append("- If the user asks you to \"forget\" something, use the delete_memory tool.")
        lines.append("- Don't explicitly mention \"according to memory\" — just apply it naturally.")

        return lines.joined(separator: "\n")
    }
}
