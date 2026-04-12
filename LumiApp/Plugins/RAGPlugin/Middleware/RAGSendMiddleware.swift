import Foundation
import MagicKit
import os

/// RAG 中间件
///
/// 集成到消息发送管线，自动检索相关文档。
///
/// ## 工作流程
/// 1. 拦截用户消息
/// 2. 使用 RAGIntentAnalyzer 判断是否需要 RAG 检索
/// 3. 检查 RAG 服务是否已初始化
/// 4. 如果未初始化，跳过 RAG（中间件不负责初始化）
/// 5. 检查索引状态
/// 6. 如果索引未完成，启动后台索引，不阻塞发送流程
/// 7. 如果索引已完成，调用 RAG 服务检索相关文档
/// 8. 将检索结果附加到消息上下文
@MainActor
final class RAGSendMiddleware: SendMiddleware, SuperLog {
    nonisolated static let emoji = "🦞"
    nonisolated static let verbose: Bool = false
    let id = "rag"
    let order: Int = 100

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // ⏱️ 总耗时开始
        let totalStart = CFAbsoluteTimeGetCurrent()

        let userMessage = ctx.message.content
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if Self.verbose {
            RAGPlugin.logger.info("\(Self.t)🔀 RAG 中间件：检查消息")
            RAGPlugin.logger.info("\(Self.t)   用户消息：\"\(userMessage)\"")
            RAGPlugin.logger.info("\(Self.t)   项目路径：\(projectPath.isEmpty ? "<未选择>" : projectPath)")
        }

        // 使用 RAGIntentAnalyzer 判断是否需要 RAG
        guard RAGIntentAnalyzer.shouldUseRAG(for: userMessage) else {
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (不符合触发条件)")
            }
            await next(ctx)
            return
        }

        guard !projectPath.isEmpty else {
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (未选择项目)")
            }
            await next(ctx)
            return
        }

        // 获取 RAG 服务
        let ragService = RAGPlugin.getService()

        // 检查服务是否已初始化（nonisolated 属性，无需 await）
        let isInitialized = ragService.isInitialized
        if !isInitialized {
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (服务未初始化)")
                RAGPlugin.logger.info("\(Self.t)   💡 提示：RAG 服务由插件在适当时机初始化，中间件不负责初始化")
            }
            await next(ctx)
            return
        }

        // ⏱️ 记录索引检查时间
        let indexingCheckStart = CFAbsoluteTimeGetCurrent()
        let isAnyIndexing = RAGService.isAnyIndexing()
        let isProjectIndexing = RAGService.isIndexing(projectPath: projectPath)
        let indexingCheckDuration = (CFAbsoluteTimeGetCurrent() - indexingCheckStart) * 1000

        if Self.verbose {
            RAGPlugin.logger.info("\(Self.t)   🔍 索引状态检查：anyIndexing=\(isAnyIndexing), projectIndexing=\(isProjectIndexing) (\(String(format: "%.2f", indexingCheckDuration))ms)")
        }

        // 只要任意项目正在索引，都直接跳过本轮 RAG，避免卡在 RAGService actor 队列
        if isAnyIndexing {
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (存在后台索引任务，不阻塞发送)")
            }
            await next(ctx)
            return
        }
        // 索引进行中时，发送链路应直接放行，避免等待 RAGService actor 队列
        if isProjectIndexing {
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (索引进行中，不阻塞发送)")
            }
            await next(ctx)
            return
        }

        if Self.verbose {
            RAGPlugin.logger.info("\(Self.t)   ✅ 触发 RAG 检索")
        }

        do {
            // ⏱️ checkNeedsIndex 耗时
            let checkStart = CFAbsoluteTimeGetCurrent()
            let needsIndex = try await ragService.checkNeedsIndex(projectPath: projectPath)
            let checkDuration = (CFAbsoluteTimeGetCurrent() - checkStart) * 1000
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏱️ checkNeedsIndex 耗时：\(String(format: "%.2f", checkDuration))ms, needsIndex=\(needsIndex)")
            }

            if needsIndex {
                // 需要索引，启动后台索引任务，不阻塞发送流程
                if Self.verbose {
                    RAGPlugin.logger.info("\(Self.t)   🔄 索引未完成，启动后台索引任务")
                }
                await ragService.ensureIndexedBackground(projectPath: projectPath)

                // 直接继续发送流程（不使用 RAG）
                if Self.verbose {
                    RAGPlugin.logger.info("\(Self.t)   ⏭️ 后台索引中，跳过本次 RAG 检索")
                }
                await next(ctx)
                return
            }

            // ⏱️ retrieve 耗时（这是最关键的指标）
            let retrieveStart = CFAbsoluteTimeGetCurrent()
            // 索引已完成，执行检索
            let response = try await ragService.retrieve(
                query: userMessage,
                projectPath: projectPath,
                topK: 5
            )
            let retrieveDuration = (CFAbsoluteTimeGetCurrent() - retrieveStart) * 1000

            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏱️ retrieve 耗时：\(String(format: "%.2f", retrieveDuration))ms")
            }

            // ⚠️ 性能预警：超过 300ms 显示警告
            if Self.verbose, retrieveDuration > 300 {
                RAGPlugin.logger.warning("\(Self.t)   ⚠️ RAG 检索耗时过长：\(String(format: "%.2f", retrieveDuration))ms (>300ms)")
            }

            guard response.hasResults else {
                if Self.verbose {
                    RAGPlugin.logger.info("\(Self.t)   ⚠️ 未找到相关文档")
                }
                await next(ctx)
                return
            }

            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   📄 找到 \(response.results.count) 个相关文档:")
                for (index, result) in response.results.enumerated() {
                    RAGPlugin.logger.info("\(Self.t)      [\(index + 1)] \(result.source) (相似度：\(String(format: "%.2f", result.score)))")
                    RAGPlugin.logger.info("\(Self.t)          \(result.content.prefix(50))...")
                }
            }

            let augmentedPrompt = RAGContextBuilder.buildPrompt(
                query: userMessage,
                results: response.results,
                projectPath: projectPath
            )
            ctx.transientSystemPrompts.append(augmentedPrompt)

            // ⏱️ 总耗时
            let totalDuration = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)   📝 已构建增强提示词 (\(augmentedPrompt.count) 字符)")
                RAGPlugin.logger.info("\(Self.t)   🧩 已注入本轮临时 system 上下文")
                RAGPlugin.logger.info("\(Self.t)   ⏱️ RAG 中间件总耗时：\(String(format: "%.2f", totalDuration))ms")
                RAGPlugin.logger.info("\(Self.t)   ➡️ 继续传递给 LLM...")
            }
        } catch {
            // ⏱️ 错误也要记录耗时
            let totalDuration = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000
            RAGPlugin.logger.error("\(Self.t)   ❌ RAG 检索失败：\(error) (耗时：\(String(format: "%.2f", totalDuration))ms)")
        }

        await next(ctx)
    }
}
