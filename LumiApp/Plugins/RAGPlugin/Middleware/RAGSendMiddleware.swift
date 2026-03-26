import MagicKit
import os

/// RAG 中间件
///
/// 集成到消息发送管线，自动检索相关文档。
///
/// ## 工作流程
/// 1. 拦截用户消息
/// 2. 判断是否需要 RAG 检索
/// 3. 调用 Context 中的 ragService 检索相关文档
/// 4. 将检索结果附加到消息上下文
@MainActor
final class RAGSendMiddleware: SendMiddleware, SuperLog {
    nonisolated static let emoji = "🦞"
    nonisolated static let verbose = false

    let id = "rag"
    let order: Int = 100

    /// 触发 RAG 的关键词
    private let ragTriggers = ["项目", "代码", "功能", "文件", "实现", "在哪", "怎么", "如何"]

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let userMessage = ctx.message.content
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        RAGPlugin.logger.info("🔀 RAG 中间件：检查消息")
        RAGPlugin.logger.info("\(Self.t)   用户消息：\"\(userMessage)\"")

        guard shouldUseRAG(for: userMessage) else {
            RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (不符合触发条件)")
            await next(ctx)
            return
        }
        guard !projectPath.isEmpty else {
            RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (未选择项目)")
            await next(ctx)
            return
        }

        RAGPlugin.logger.info("\(Self.t)   ✅ 触发 RAG 检索")

        do {
            try await ctx.ragService.initialize()
            try await ctx.ragService.ensureIndexed(projectPath: projectPath)

            let response = try await ctx.ragService.retrieve(
                query: userMessage,
                projectPath: projectPath,
                topK: 5
            )

            guard response.hasResults else {
                RAGPlugin.logger.info("\(Self.t)   ⚠️ 未找到相关文档")
                await next(ctx)
                return
            }

            RAGPlugin.logger.info("\(Self.t)   📄 找到 \(response.results.count) 个相关文档:")
            for (index, result) in response.results.enumerated() {
                RAGPlugin.logger.info("\(Self.t)      [\(index + 1)] \(result.source) (相似度：\(String(format: "%.2f", result.score)))")
                RAGPlugin.logger.info("\(Self.t)          \(result.content.prefix(50))...")
            }

            let augmentedPrompt = RAGContextBuilder.buildPrompt(
                query: userMessage,
                results: response.results,
                projectPath: projectPath
            )
            ctx.transientSystemPrompts.append(augmentedPrompt)

            RAGPlugin.logger.info("\(Self.t)   📝 已构建增强提示词 (\(augmentedPrompt.count) 字符)")
            RAGPlugin.logger.info("\(Self.t)   🧩 已注入本轮临时 system 上下文")
            RAGPlugin.logger.info("\(Self.t)   ➡️ 继续传递给 LLM...")

        } catch {
            RAGPlugin.logger.error("\(Self.t)   ❌ RAG 检索失败：\(error)")
        }

        await next(ctx)
    }

    // MARK: - 私有方法

    private func shouldUseRAG(for message: String) -> Bool {
        let lowercased = message.lowercased()
        return ragTriggers.contains { lowercased.contains($0) }
    }
}
