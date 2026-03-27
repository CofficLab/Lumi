import Foundation
import MagicKit
import os

/// RAG 中间件
///
/// 集成到消息发送管线，自动检索相关文档。
///
/// ## 工作流程
/// 1. 拦截用户消息
/// 2. 判断是否需要 RAG 检索
/// 3. 检查索引状态
/// 4. 如果索引未完成，启动后台索引，不阻塞发送流程
/// 5. 如果索引已完成，调用 RAG 服务检索相关文档
/// 6. 将检索结果附加到消息上下文
@MainActor
final class RAGSendMiddleware: SendMiddleware, SuperLog {
    nonisolated static let emoji = "🦞"
    nonisolated static let verbose = false

    let id = "rag"
    let order: Int = 100

    /// 中文高意图触发词
    private let ragTriggersZH = [
        "项目", "代码", "功能", "文件", "实现", "在哪", "怎么", "如何", "为什么", "报错", "错误",
        "修复", "定位", "模块", "接口", "逻辑", "流程", "类", "方法", "函数", "目录", "路径"
    ]

    /// 英文高意图触发词
    private let ragTriggersEN = [
        "project", "code", "file", "files", "implementation", "implement", "where", "how", "why",
        "function", "method", "class", "module", "folder", "directory", "path", "api",
        "bug", "error", "issue", "fix", "refactor", "stack trace", "exception"
    ]

    /// 问句线索
    private let questionMarkers = [
        "?", "？", "怎么", "如何", "为什么", "why", "how", "where", "what", "which", "can you", "could you"
    ]

    /// 与代码检索相关的语义线索
    private let codeIntentMarkers = [
        "func ", "class ", "struct ", "enum ", "protocol ", "import ", "throws ", "return ",
        "def ", "function ", "interface ", "extends ", "namespace ", "package ", "```"
    ]

    private let codeFileExtensions = [
        ".swift", ".m", ".mm", ".h", ".hpp", ".c", ".cc", ".cpp", ".js", ".ts", ".tsx", ".jsx",
        ".json", ".yaml", ".yml", ".toml", ".md", ".py", ".rb", ".go", ".rs", ".java", ".kt",
        ".sql", ".html", ".css", ".scss", ".xml", ".sh", ".zsh"
    ]

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let userMessage = ctx.message.content
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        RAGPlugin.logger.info("\(Self.t)🔀 RAG 中间件：检查消息")
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
        // 索引进行中时，发送链路应直接放行，避免等待 RAGService actor 队列
        if RAGService.isIndexing(projectPath: projectPath) {
            RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (索引进行中，不阻塞发送)")
            await next(ctx)
            return
        }

        RAGPlugin.logger.info("\(Self.t)   ✅ 触发 RAG 检索")

        do {
            // 从插件内部获取 RAG 服务
            let ragService = RAGPlugin.getService()

            try await ragService.initialize()

            // 检查是否需要索引
            let needsIndex = try await ragService.checkNeedsIndex(projectPath: projectPath)

            if needsIndex {
                // 需要索引，启动后台索引任务，不阻塞发送流程
                RAGPlugin.logger.info("\(Self.t)   🔄 索引未完成，启动后台索引任务")
                await ragService.ensureIndexedBackground(projectPath: projectPath)

                // 直接继续发送流程（不使用 RAG）
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 后台索引中，跳过本次 RAG 检索")
                await next(ctx)
                return
            }

            // 索引已完成，执行检索
            let response = try await ragService.retrieve(
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
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lowercased = trimmed.lowercased()

        if ragTriggersZH.contains(where: { lowercased.contains($0) }) { return true }
        if ragTriggersEN.contains(where: { lowercased.contains($0) }) { return true }
        if hasFileOrPathReference(lowercased) { return true }
        if codeIntentMarkers.contains(where: { lowercased.contains($0) }) { return true }

        let hasQuestion = questionMarkers.contains(where: { lowercased.contains($0) })
        if hasQuestion, containsCodeIntentWord(lowercased) { return true }

        return false
    }

    private func hasFileOrPathReference(_ message: String) -> Bool {
        if message.contains("/") || message.contains("\\") { return true }
        return codeFileExtensions.contains(where: { message.contains($0) })
    }

    private func containsCodeIntentWord(_ message: String) -> Bool {
        let intentWords = [
            "代码", "文件", "实现", "函数", "方法", "类", "模块", "接口", "错误", "报错",
            "code", "file", "implementation", "function", "method", "class", "module", "api", "error", "bug"
        ]
        return intentWords.contains(where: { message.contains($0) })
    }
}
