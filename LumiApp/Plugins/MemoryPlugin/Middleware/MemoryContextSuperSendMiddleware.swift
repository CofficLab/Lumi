import Foundation
import AgentToolKit
import os

/// 记忆注入中间件
///
/// 在每次发送用户消息前，自动读取当前项目的记忆索引和相关记忆，
/// 将其格式化为系统提示词注入到 LLM 请求中。
///
/// ## 工作流程
/// 1. 拦截用户消息发送
/// 2. 从上下文获取当前项目路径
/// 3. 读取全局和项目级记忆索引
/// 4. 根据用户消息关键词检索相关记忆
/// 5. 将记忆格式化为系统提示词
/// 6. 注入到 transientSystemPrompts 中
///
/// ## 设计决策
/// - 索引全量注入（紧凑，每记忆一行），详情按需注入（top-3 相关记忆）
/// - 如果记忆目录为空，静默跳过，不阻塞发送流程
/// - order=5，在 AgentContextSync (order=1) 之后执行
@MainActor
final class MemoryContextSuperSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "🧠"
    nonisolated static let verbose: Bool = true
    let id: String = "memory-context"
    let order: Int = 5

    // MARK: - 执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        // 读取配置
        let store = MemoryPluginLocalStore.shared
        let maxRelevant = store.maxRelevantMemories
        let injectGlobal = store.shouldInjectGlobalIndex
        let injectProject = store.shouldInjectProjectIndex

        // 未选择项目时仍然注入全局记忆
        let lang = ctx.projectVM.languagePreference

        var globalIndex = ""
        var projectIndex = ""
        var globalRelevant: [MemoryItem] = []
        var projectRelevant: [MemoryItem] = []

        // 读取全局记忆索引
        if injectGlobal {
            globalIndex = await MemoryStorageService.shared.readIndex(scope: .global)

            // 根据消息检索相关记忆
            let userMessage = ctx.message.content
            globalRelevant = await MemoryRetrievalService.shared.findRelevant(
                query: userMessage,
                scope: .global,
                maxResults: maxRelevant
            )
        }

        // 如果有项目，读取项目记忆
        if !projectPath.isEmpty && injectProject {
            let projectScope: MemoryScope = .project(projectPath)
            projectIndex = await MemoryStorageService.shared.readIndex(scope: projectScope)

            // 根据消息检索相关记忆
            let userMessage = ctx.message.content
            projectRelevant = await MemoryRetrievalService.shared.findRelevant(
                query: userMessage,
                scope: projectScope,
                maxResults: maxRelevant
            )
        }

        // 检查是否有任何记忆
        let hasAnyMemory = !globalIndex.isEmpty || !projectIndex.isEmpty

        guard hasAnyMemory else {
            if Self.verbose || MemoryPlugin.verbose {
                MemoryPlugin.logger.info("\(Self.t)   ⏭️ 跳过 (无记忆)")
            }
            await next(ctx)
            return
        }

        // 构建记忆提示词
        let prompt = buildMemoryPrompt(
            globalIndex: globalIndex,
            projectIndex: projectIndex,
            globalRelevant: globalRelevant,
            projectRelevant: projectRelevant,
            languagePreference: lang
        )

        if !prompt.isEmpty {
            ctx.transientSystemPrompts.append(prompt)

            if Self.verbose || MemoryPlugin.verbose {
                let totalRelevant = globalRelevant.count + projectRelevant.count
                MemoryPlugin.logger.info("\(Self.t)   ✅ 已注入记忆提示词 (\(totalRelevant) 条相关记忆)")
                MemoryPlugin.logger.info("\(Self.t)   📝 提示词长度：\(prompt.count) 字符")
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
        languagePreference: LanguagePreference
    ) -> String {
        switch languagePreference {
        case .chinese:
            return buildChinesePrompt(
                globalIndex: globalIndex,
                projectIndex: projectIndex,
                globalRelevant: globalRelevant,
                projectRelevant: projectRelevant
            )
        case .english:
            return buildEnglishPrompt(
                globalIndex: globalIndex,
                projectIndex: projectIndex,
                globalRelevant: globalRelevant,
                projectRelevant: projectRelevant
            )
        }
    }

    private func buildChinesePrompt(
        globalIndex: String,
        projectIndex: String,
        globalRelevant: [MemoryItem],
        projectRelevant: [MemoryItem]
    ) -> String {
        var lines: [String] = []

        lines.append("## 记忆系统")
        lines.append("")
        lines.append("你有一个持久化的文件记忆系统。你可以使用 `save_memory`、`recall_memory`、`list_memories` 和 `delete_memory` 工具来管理记忆。")
        lines.append("")

        // 全局记忆
        if !globalIndex.isEmpty {
            lines.append("### 全局记忆索引")
            lines.append("")
            // 去掉索引文件的标题行（# Global Memory Index），直接展示内容
            let content = globalIndex
                .components(separatedBy: .newlines)
                .filter { !$0.hasPrefix("# ") }
                .joined(separator: "\n")
            lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        // 项目记忆
        if !projectIndex.isEmpty {
            lines.append("### 项目记忆索引")
            lines.append("")
            let content = projectIndex
                .components(separatedBy: .newlines)
                .filter { !$0.hasPrefix("# ") }
                .joined(separator: "\n")
            lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        // 相关记忆详情
        let allRelevant = globalRelevant + projectRelevant
        if !allRelevant.isEmpty {
            lines.append("### 相关记忆（本次对话特别相关）")
            lines.append("")
            for memory in allRelevant {
                lines.append(memory.formattedContent())
                lines.append("")
            }
        }

        // 使用规则
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
        projectRelevant: [MemoryItem]
    ) -> String {
        var lines: [String] = []

        lines.append("## Memory System")
        lines.append("")
        lines.append("You have a persistent file-based memory system. You can use `save_memory`, `recall_memory`, `list_memories`, and `delete_memory` tools to manage memories.")
        lines.append("")

        if !globalIndex.isEmpty {
            lines.append("### Global Memory Index")
            lines.append("")
            let content = globalIndex
                .components(separatedBy: .newlines)
                .filter { !$0.hasPrefix("# ") }
                .joined(separator: "\n")
            lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        if !projectIndex.isEmpty {
            lines.append("### Project Memory Index")
            lines.append("")
            let content = projectIndex
                .components(separatedBy: .newlines)
                .filter { !$0.hasPrefix("# ") }
                .joined(separator: "\n")
            lines.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }

        let allRelevant = globalRelevant + projectRelevant
        if !allRelevant.isEmpty {
            lines.append("### Relevant Memories (particularly relevant to this conversation)")
            lines.append("")
            for memory in allRelevant {
                lines.append(memory.formattedContent())
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
