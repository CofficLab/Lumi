import Foundation
import MagicKit

// MARK: - 重试策略

/// 流式 LLM 请求的重试策略。
struct StreamRetryPolicy: Sendable {
    /// 最大重试次数
    let maxRetries: Int
    /// 初始等待时间（秒）
    let baseDelay: Double
    /// 退避倍数
    let backoffMultiplier: Double

    static let `default` = StreamRetryPolicy(
        maxRetries: 3,
        baseDelay: 2.0,
        backoffMultiplier: 2.0
    )

    /// 计算第 N 次重试的等待时间（指数退避 + 随机抖动）
    func delay(for attempt: Int) -> Double {
        let exponential = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        let jitter = Double.random(in: 0 ... 1.0)
        return exponential + jitter
    }
}

// MARK: - 请求结果

/// LLM 请求的结果：成功返回助手消息，取消或失败则返回对应信息。
enum LLMRequestResult {
    case success(ChatMessage)
    case cancelled
    case failed(Error)
}

// MARK: - LLMRequester

/// 封装「向 LLM 发一次流式请求」的全部细节，含重试、状态更新、后置管线。
///
/// 调用方只需关心 `LLMRequestResult`，不需要知道重试、退避、Metadata 等内部细节。
@MainActor
final class LLMRequester: SuperLog {
    nonisolated static let emoji = "🧠"

    private let llmService: LLMService
    let agentSessionConfig: LLMVM
    private let toolService: ToolService
    private let pluginVM: PluginVM
    private let statusVM: ConversationStatusVM
    private let retryPolicy: StreamRetryPolicy

    init(
        llmService: LLMService,
        agentSessionConfig: LLMVM,
        toolService: ToolService,
        pluginVM: PluginVM,
        statusVM: ConversationStatusVM,
        retryPolicy: StreamRetryPolicy = .default
    ) {
        self.llmService = llmService
        self.agentSessionConfig = agentSessionConfig
        self.toolService = toolService
        self.pluginVM = pluginVM
        self.statusVM = statusVM
        self.retryPolicy = retryPolicy
    }

    // MARK: - 公开接口

    /// 向 LLM 发送一次流式请求（含重试）。
    ///
    /// - Parameters:
    ///   - conversationId: 会话 ID
    ///   - messages: 发给 LLM 的消息列表
    ///   - additionalSystemPrompts: 临时系统提示词（不落库）
    /// - Returns: `.success(助手消息)` / `.cancelled` / `.failed(错误)`
    func request(
        conversationId: UUID,
        messages: [ChatMessage],
        additionalSystemPrompts: [String] = []
    ) async -> LLMRequestResult {
        let messagesForLLM = Self.composeMessagesForLLM(
            conversationId: conversationId,
            baseMessages: messages,
            additionalSystemPrompts: additionalSystemPrompts
        )
        let config = agentSessionConfig.getCurrentConfig()
        let availableTools = ToolAvailabilityGuard().evaluate(
            tools: toolService.tools,
            allowsTools: agentSessionConfig.chatMode.allowsTools,
            isFinalStep: false
        )
        let toolsArg = availableTools.isEmpty ? nil : availableTools

        let onStreamChunk = makeStreamChunkHandler(conversationId: conversationId)
        let startTime = CFAbsoluteTimeGetCurrent()
        let metadataHolder = MetadataHolder()
        let middlewares = pluginVM.getSuperSendMiddlewares()

        // ── 重试循环 ──
        var lastError: Error?

        for attempt in 1 ... retryPolicy.maxRetries {
            if Task.isCancelled {
                return handleCancelled(
                    conversationId: conversationId,
                    metadataHolder: metadataHolder,
                    startTime: startTime,
                    middlewares: middlewares
                )
            }

            do {
                updateStatusBeforeRequest(conversationId: conversationId, attempt: attempt)

                let assistantMessage = try await llmService.sendStreamingMessage(
                    messages: messagesForLLM,
                    config: config,
                    tools: toolsArg,
                    onChunk: onStreamChunk,
                    onRequestStart: makeRequestStartHandler(
                        conversationId: conversationId,
                        metadataHolder: metadataHolder
                    )
                )

                // 成功 → 调用后置管线
                await Self.runPostPipeline(
                    metadataHolder: metadataHolder,
                    startTime: startTime,
                    response: assistantMessage,
                    error: nil,
                    middlewares: middlewares
                )

                return .success(assistantMessage)

            } catch LLMServiceError.cancelled {
                return handleCancelled(
                    conversationId: conversationId,
                    metadataHolder: metadataHolder,
                    startTime: startTime,
                    middlewares: middlewares
                )

            } catch {
                lastError = error

                guard attempt < retryPolicy.maxRetries, Self.isRetryable(error) else {
                    break
                }

                let delay = retryPolicy.delay(for: attempt)
                AppLogger.core.info("\(Self.t) ⚠️ 流式请求失败（第 \(attempt) 次），\(Int(delay)) 秒后重试：\(error.localizedDescription)")
                statusVM.setStatus(conversationId: conversationId, content: "请求失败，\(Int(delay)) 秒后重试 (\(attempt + 1)/\(retryPolicy.maxRetries))…")

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return .cancelled
                }
            }
        }

        // ── 重试耗尽 ──
        guard let error = lastError else { return .cancelled }

        AppLogger.core.error("\(Self.t) 请求模型最终失败：\(error.localizedDescription)")

        await Self.runPostPipeline(
            metadataHolder: metadataHolder,
            startTime: startTime,
            response: nil,
            error: error,
            middlewares: middlewares
        )

        return .failed(error)
    }

    // MARK: - 私有辅助

    private func makeStreamChunkHandler(conversationId: UUID) -> @Sendable (StreamChunk) async -> Void {
        let statusVM = self.statusVM
        return { chunk in
            await MainActor.run {
                statusVM.applyStreamChunk(conversationId: conversationId, chunk: chunk)
            }
        }
    }

    private func makeRequestStartHandler(
        conversationId: UUID,
        metadataHolder: MetadataHolder
    ) -> @Sendable (RequestMetadata) async -> Void {
        let statusVM = self.statusVM
        return { metadata in
            await metadataHolder.set(metadata)
            await MainActor.run {
                statusVM.setStatus(conversationId: conversationId, content: "正在发送消息，大小：\(metadata.formattedBodySize)")
            }
        }
    }

    private func updateStatusBeforeRequest(conversationId: UUID, attempt: Int) {
        if attempt == 1 {
            statusVM.setStatus(conversationId: conversationId, content: "正在发送消息…")
        } else {
            statusVM.setStatus(conversationId: conversationId, content: "正在重试 (\(attempt)/\(retryPolicy.maxRetries))…")
        }
    }

    private func handleCancelled(
        conversationId: UUID,
        metadataHolder: MetadataHolder,
        startTime: CFAbsoluteTime,
        middlewares: [SuperSendMiddleware]
    ) -> LLMRequestResult {
        AppLogger.core.info("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 发送已取消")
        statusVM.setStatus(conversationId: conversationId, content: "已停止生成")

        Task {
            await Self.runPostPipeline(
                metadataHolder: metadataHolder,
                startTime: startTime,
                response: nil,
                error: LLMServiceError.cancelled,
                middlewares: middlewares
            )
        }

        return .cancelled
    }

    /// 调用后置管线（静态方法，避免捕获 self）
    private static func runPostPipeline(
        metadataHolder: MetadataHolder,
        startTime: CFAbsoluteTime,
        response: ChatMessage?,
        error: Error?,
        middlewares: [SuperSendMiddleware]
    ) async {
        guard let metadata = await metadataHolder.get() else { return }
        var mutableMetadata = metadata
        mutableMetadata.duration = CFAbsoluteTimeGetCurrent() - startTime
        if let error {
            mutableMetadata.error = error
            if let apiError = error as? APIError,
               case let .httpError(statusCode, _) = apiError {
                mutableMetadata.responseStatusCode = statusCode
            }
        }
        let pipeline = SendPipeline(middlewares: middlewares)
        await pipeline.runPost(metadata: mutableMetadata, response: response)
    }

    // MARK: - 重试判断（纯函数，无状态）

    /// 判断错误是否可重试。
    ///
    /// 可重试：
    /// - 网络层：超时、断网、连接丢失
    /// - HTTP 层：429 速率限制、5xx 服务端错误
    ///
    /// 不可重试：
    /// - 配置错误（API Key 为空、模型为空等）
    /// - 用户取消
    /// - 客户端 4xx 错误（非 429）
    static func isRetryable(_ error: Error) -> Bool {
        // ── LLMServiceError ──
        if let llmError = error as? LLMServiceError {
            switch llmError {
            case .requestFailed: return true
            case .cancelled:     return false
            default:             return false // 配置类错误不重试
            }
        }

        // ── APIError（由 LLMAPIService 直接抛出）──
        if let apiError = error as? APIError {
            switch apiError {
            case let .httpError(statusCode, _):
                if statusCode == 429 { return true }
                if (500 ... 599).contains(statusCode) { return true }
                return false
            case let .requestFailed(underlying):
                // 网络层错误：超时、断网、连接丢失
                let nsError = underlying as NSError
                if nsError.code == NSURLErrorTimedOut { return true }
                if nsError.code == NSURLErrorNotConnectedToInternet { return true }
                if nsError.code == NSURLErrorCannotConnectToHost { return true }
                if nsError.code == NSURLErrorNetworkConnectionLost { return true }
                return false
            default:
                return false
            }
        }

        return false
    }

    // MARK: - 消息组装

    static func composeMessagesForLLM(
        conversationId: UUID,
        baseMessages: [ChatMessage],
        additionalSystemPrompts: [String]
    ) -> [ChatMessage] {
        guard !additionalSystemPrompts.isEmpty else { return baseMessages }
        guard !baseMessages.isEmpty else { return baseMessages }

        var merged = baseMessages
        let insertionIndex = max(merged.count - 1, 0)
        let transientMessages = additionalSystemPrompts.map {
            ChatMessage(role: .system, conversationId: conversationId, content: $0)
        }
        merged.insert(contentsOf: transientMessages, at: insertionIndex)
        return merged
    }
}
