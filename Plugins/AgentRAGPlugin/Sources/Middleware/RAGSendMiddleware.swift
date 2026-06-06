import AgentToolKit
import Foundation
import LumiCoreKit
import RAGKit
import SuperLogKit
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
/// 7. 如果索引已完成，调用 RAG 服务检索相关文档（带超时保护）
/// 8. 将检索结果附加到消息上下文
@MainActor
public final class RAGSuperSendMiddleware: SuperSendMiddleware, SuperLog {
    public nonisolated static let emoji = "🦞"
    public nonisolated static let verbose: Bool = false
    public let id = "rag"
    public let order: Int = 100

    /// 中间件 RAG 检索的最大容忍时间（秒）
    private static let maxMiddlewareTimeoutSeconds: TimeInterval = 10

    public func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // ⏱️ 总耗时开始
        let totalStart = CFAbsoluteTimeGetCurrent()

        let userMessage = ctx.message.content
        let projectPath = RAGPluginRuntime.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if Self.verbose, RAGPlugin.verbose {
            RAGPlugin.logger.info("\(Self.t)🔀 RAG 中间件：检查消息")
            RAGPlugin.logger.info("\(Self.t)   用户消息：\"\(userMessage)\"")
            RAGPlugin.logger.info("\(Self.t)   项目路径：\(projectPath.isEmpty ? "<未选择>" : projectPath)")
        }

        // 使用 RAGIntentAnalyzer 判断是否需要 RAG
        guard RAGIntentAnalyzer.shouldUseRAG(for: userMessage) else {
            if Self.verbose, RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (不符合触发条件)")
            }
            await next(ctx)
            return
        }

        guard !projectPath.isEmpty else {
            if Self.verbose, RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (未选择项目)")
            }
            await next(ctx)
            return
        }

        // 获取 RAG 服务
        let ragService = RAGPlugin.getService()

        // 检查服务是否已初始化（nonisolated 属性，无需 await）
        guard ragService.isInitialized else {
            if Self.verbose, RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (服务未初始化)")
                RAGPlugin.logger.info("\(Self.t)   💡 提示：RAG 服务由插件在适当时机初始化，中间件不负责初始化")
            }
            await next(ctx)
            return
        }

        // 快速检查：非阻塞地检查是否正在索引（不进入 actor 队列）
        if RAGService.isAnyIndexing() || RAGService.isIndexing(projectPath: projectPath) {
            if Self.verbose, RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏭️ 跳过 RAG (后台索引进行中，不阻塞发送)")
            }
            await next(ctx)
            return
        }

        if Self.verbose, RAGPlugin.verbose {
            RAGPlugin.logger.info("\(Self.t)   ✅ 触发 RAG 检索")
        }

        // 带超时保护执行 RAG 检索，超时后直接放行
        let ragResult = await RAGTimeout.withTimeout(seconds: Self.maxMiddlewareTimeoutSeconds) {
            await self.performRAGRetrieval(
                ragService: ragService,
                projectPath: projectPath,
                userMessage: userMessage,
                totalStart: totalStart,
                languagePreference: ctx.languagePreference.ragPreference
            )
        }

        switch ragResult {
        case .success(let outcome):
            switch outcome {
            case .augmented(let prompt):
                ctx.transientSystemPrompts.append(prompt)
                let totalDuration = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000
                if Self.verbose, RAGPlugin.verbose {
                    RAGPlugin.logger.info("\(Self.t)   📝 已构建增强提示词 (\(prompt.count) 字符)")
                    RAGPlugin.logger.info("\(Self.t)   🧩 已注入本轮临时 system 上下文")
                    RAGPlugin.logger.info("\(Self.t)   ⏱️ RAG 中间件总耗时：\(String(format: "%.2f", totalDuration))ms")
                    RAGPlugin.logger.info("\(Self.t)   ➡️ 继续传递给 LLM...")
                }
            case .backgroundIndexing, .noResults, .error:
                break // 直接放行，不注入 RAG 上下文
            }

        case .timedOut:
            let totalDuration = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000
            RAGPlugin.logger.warning("\(Self.t)   ⚠️ RAG 中间件超时 (\(String(format: "%.1f", totalDuration))ms > \(Int(Self.maxMiddlewareTimeoutSeconds))s)，直接放行")
        }

        await next(ctx)
    }

    // MARK: - RAG Retrieval Logic

    private enum RAGOutcome: Sendable {
        case augmented(String)
        case backgroundIndexing
        case noResults
        case error
    }

    private func performRAGRetrieval(
        ragService: RAGService,
        projectPath: String,
        userMessage: String,
        totalStart: CFAbsoluteTime,
        languagePreference: RAGLanguagePreference
    ) async -> RAGOutcome {
        do {
            // ⏱️ checkNeedsIndex 耗时
            let checkStart = CFAbsoluteTimeGetCurrent()
            let needsIndex = try await ragService.checkNeedsIndex(projectPath: projectPath)
            let checkDuration = (CFAbsoluteTimeGetCurrent() - checkStart) * 1000
            if Self.verbose, RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏱️ checkNeedsIndex 耗时：\(String(format: "%.2f", checkDuration))ms, needsIndex=\(needsIndex)")
            }

            if needsIndex {
                // 需要索引，启动后台索引任务，不阻塞发送流程
                if Self.verbose, RAGPlugin.verbose {
                    RAGPlugin.logger.info("\(Self.t)   🔄 索引未完成，启动后台索引任务")
                }
                await ragService.ensureIndexedBackground(projectPath: projectPath)
                if Self.verbose, RAGPlugin.verbose {
                    RAGPlugin.logger.info("\(Self.t)   ⏭️ 后台索引中，跳过本次 RAG 检索")
                }
                return .backgroundIndexing
            }

            // ⏱️ retrieve 耗时（这是最关键的指标）
            let retrieveStart = CFAbsoluteTimeGetCurrent()
            let response = try await ragService.retrieve(
                query: userMessage,
                projectPath: projectPath,
                topK: 5
            )
            let retrieveDuration = (CFAbsoluteTimeGetCurrent() - retrieveStart) * 1000

            if Self.verbose, RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)   ⏱️ retrieve 耗时：\(String(format: "%.2f", retrieveDuration))ms")
            }

            // ⚠️ 性能预警：超过 300ms 显示警告
            if Self.verbose, RAGPlugin.verbose, retrieveDuration > 300 {
                RAGPlugin.logger.warning("\(Self.t)   ⚠️ RAG 检索耗时过长：\(String(format: "%.2f", retrieveDuration))ms (>300ms)")
            }

            guard response.hasResults else {
                if Self.verbose, RAGPlugin.verbose {
                    RAGPlugin.logger.info("\(Self.t)   ⚠️ 未找到相关文档")
                }
                return .noResults
            }

            if Self.verbose, RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)   📄 找到 \(response.results.count) 个相关文档:")
                for (index, result) in response.results.enumerated() {
                    RAGPlugin.logger.info("\(Self.t)      [\(index + 1)] \(result.source) (相似度：\(String(format: "%.2f", result.score)))")
                    RAGPlugin.logger.info("\(Self.t)          \(result.content.prefix(50))...")
                }
            }

            let augmentedPrompt = RAGContextBuilder.buildPrompt(
                query: userMessage,
                results: response.results,
                projectPath: projectPath,
                languagePreference: languagePreference
            )
            return .augmented(augmentedPrompt)

        } catch {
            let totalDuration = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000
            RAGPlugin.logger.error("\(Self.t)   ❌ RAG 检索失败：\(error) (耗时：\(String(format: "%.2f", totalDuration))ms)")
            return .error
        }
    }
}

private extension LanguagePreference {
    var ragPreference: RAGLanguagePreference {
        switch self {
        case .chinese:
            return .chinese
        case .english:
            return .english
        }
    }
}
