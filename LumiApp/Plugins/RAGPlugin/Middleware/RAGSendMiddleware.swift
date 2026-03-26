import MagicKit

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
final class RAGSendMiddleware: SendMiddleware {
    
    let id = "rag"
    let order: Int = 100
    
    private let plugin: RAGPlugin
    
    /// 触发 RAG 的关键词
    private let ragTriggers = ["项目", "代码", "功能", "文件", "实现", "在哪", "怎么", "如何"]
    
    init(plugin: RAGPlugin) {
        self.plugin = plugin
    }
    
    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let isEnabled = await plugin.checkEnabled()
        guard isEnabled else {
            await next(ctx)
            return
        }
        
        let userMessage = ctx.message.content
        
        AppLogger.rag.info("🔀 RAG 中间件：检查消息")
        AppLogger.rag.info("   用户消息：\"\(userMessage)\"")
        
        guard shouldUseRAG(for: userMessage) else {
            AppLogger.rag.info("   ⏭️ 跳过 RAG (不符合触发条件)")
            await next(ctx)
            return
        }
        
        AppLogger.rag.info("   ✅ 触发 RAG 检索")
        
        do {
            try await ctx.ragService.initialize()
            
            let response = try await ctx.ragService.retrieve(query: userMessage, topK: 3)
            
            guard response.hasResults else {
                AppLogger.rag.info("   ⚠️ 未找到相关文档")
                await next(ctx)
                return
            }
            
            AppLogger.rag.info("   📄 找到 \(response.results.count) 个相关文档:")
            for (index, result) in response.results.enumerated() {
                AppLogger.rag.info("      [\(index + 1)] \(result.source) (相似度：\(String(format: "%.2f", result.score)))")
                AppLogger.rag.info("          \(result.content.prefix(50))...")
            }
            
            let augmentedPrompt = buildAugmentedPrompt(query: userMessage, results: response.results)
            
            AppLogger.rag.info("   📝 已构建增强提示词 (\(augmentedPrompt.count) 字符)")
            AppLogger.rag.info("   ➡️ 继续传递给 LLM...")
            
        } catch {
            AppLogger.rag.error("   ❌ RAG 检索失败：\(error)")
        }
        
        await next(ctx)
    }
    
    // MARK: - 私有方法
    
    private func shouldUseRAG(for message: String) -> Bool {
        let lowercased = message.lowercased()
        return ragTriggers.contains { lowercased.contains($0) }
    }
    
    private func buildAugmentedPrompt(query: String, results: [RAGSearchResult]) -> String {
        var prompt = "基于以下相关文档回答用户问题:\n\n---\n相关文档:\n"
        
        for (index, result) in results.enumerated() {
            prompt += "\n[文档 \(index + 1)] 来源：\(result.source)\n\(result.content)\n"
        }
        
        prompt += "\n---\n用户问题：\(query)\n\n请基于以上文档内容回答。"
        
        return prompt
    }
}
