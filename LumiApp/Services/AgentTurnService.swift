import AgentToolKit
import Foundation
import LLMKit
import HttpKit
import LumiCoreKit
import ModelRouterKit

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

// MARK: - AgentTurnService

/// Agent 回合服务
///
/// 驱动一轮完整的 Agent 循环：
///
/// ```
/// 用户消息 → 请求 LLM → 解析工具调用 → 执行工具 → 再请求 LLM → ... → 结束
/// ```
///
/// 这是整个对话引擎的**核心状态机**。它不关心队列调度、UI 绑定等外部细节，
/// 只专注于「读消息 → 判断下一步 → 执行 → 重复」这个循环。
///
/// ## 设计原则
///
/// - **单一入口**：`run()` 是唯一的公开方法
/// - **职责委托**：LLM 请求由内联的私有方法处理，工具执行 → `ToolCallExecutor`，收尾由内联方法完成
@MainActor
final class AgentTurnService: SuperLog {
    nonisolated static let emoji = "🔄"

    // MARK: - LLM 请求相关依赖

    private let llmService: LLMService
    private let agentSessionConfig: AppLLMVM
    private let toolService: ToolService
    private let pluginVM: AppPluginVM
    private let statusVM: WindowConversationStatusVM
    private let projectVM: WindowProjectVM
    private let retryPolicy: StreamRetryPolicy

    // MARK: - 收尾相关依赖

    private let conversationSendStatusVM: WindowConversationStatusVM

    // MARK: - 公共依赖

    private let conversationVM: WindowConversationVM
    private let messageQueueVM: WindowMessageQueueVM
    let chatHistoryService: ChatHistoryService

    // MARK: - 工具执行

    private let toolCallExecutor: ToolCallExecutor

    init(
        llmService: LLMService,
        agentSessionConfig: AppLLMVM,
        toolService: ToolService,
        pluginVM: AppPluginVM,
        statusVM: WindowConversationStatusVM,
        projectVM: WindowProjectVM,
        conversationVM: WindowConversationVM,
        messageQueueVM: WindowMessageQueueVM,
        chatHistoryService: ChatHistoryService,
        toolCallExecutor: ToolCallExecutor,
        retryPolicy: StreamRetryPolicy = .default
    ) {
        self.llmService = llmService
        self.agentSessionConfig = agentSessionConfig
        self.toolService = toolService
        self.pluginVM = pluginVM
        self.statusVM = statusVM
        self.projectVM = projectVM
        self.conversationVM = conversationVM
        self.messageQueueVM = messageQueueVM
        self.chatHistoryService = chatHistoryService
        self.toolCallExecutor = toolCallExecutor
        self.retryPolicy = retryPolicy
        self.conversationSendStatusVM = statusVM
    }

    // MARK: - 公开接口

    /// 运行一轮完整的 Agent 循环。
    ///
    /// 从数据库中读取消息历史，根据最后一条消息的角色决定下一步：
    /// - `user` / 遗留 `tool`：向 LLM 发起流式请求
    /// - `assistant`（含未完成工具调用）：执行工具并将结果写回 ToolCall
    /// - `assistant`（工具调用均已有结果）：向 LLM 发起流式请求
    /// - `assistant`（无工具调用）：对话回合结束
    ///
    /// - Parameters:
    ///   - conversationId: 会话 ID
    ///   - additionalSystemPrompts: 临时系统提示词（仅在首轮请求中使用）
    func run(conversationId: UUID, additionalSystemPrompts: [String] = []) async {
        // 消费掉临时提示词（仅第一轮使用）
        var remainingSystemPrompts = additionalSystemPrompts

        // ── Agent 循环 ──────────────────────────────────
        while true {
            // 检查是否仍在处理中
            guard messageQueueVM.isProcessing(for: conversationId) else { return }

            // 加载最新消息
            let messages = chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
            guard !messages.isEmpty else {
                AppLogger.core.error("\(Self.t) [\(conversationId)] 无消息")
                return
            }

            // 找到最后一条可驱动消息（跳过 system/status 消息）
            guard let last = messages.last(where: { $0.role != .system && $0.role != .status }) else {
                return
            }

            switch last.role {
            case .user, .tool:
                guard await requestLLM(
                    conversationId: conversationId,
                    storageMessages: messages,
                    remainingSystemPrompts: &remainingSystemPrompts
                ) else { return }

            case .assistant:
                if last.hasToolCalls {
                    if last.toolCalls?.contains(where: { $0.result == nil }) == true {
                        if await toolCallExecutor.presentPermissionIfNeeded(
                            assistantMessage: last,
                            conversationId: conversationId
                        ) {
                            return
                        }

                        let summary = await toolCallExecutor.executeAll(
                            assistantMessage: last,
                            conversationId: conversationId
                        )

                        if summary.hadUserRejection {
                            finishTurnByUserRejection(conversationId: conversationId)
                            runTurnFinishedPipeline(conversationId: conversationId, endReason: .userRejection)
                            NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
                            return
                        }

                        // 工具正在等待用户回答，暂停循环
                        if summary.hasAwaitingUserResponse {
                            conversationSendStatusVM.setStatus(
                                conversationId: conversationId,
                                content: "等待您的选择…"
                            )
                            return
                        }

                        continue
                    }

                    guard await requestLLM(
                        conversationId: conversationId,
                        storageMessages: messages,
                        remainingSystemPrompts: &remainingSystemPrompts
                    ) else { return }
                } else {
                    finishTurn(conversationId: conversationId)
                    runTurnFinishedPipeline(conversationId: conversationId, endReason: .completed)
                    NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
                    return
                }

            case .system, .status, .error, .unknown:
                return
            }
        }
    }
}

// MARK: - LLM 请求

extension AgentTurnService {
    /// - Returns: 是否应继续 Agent 循环
    private func requestLLM(
        conversationId: UUID,
        storageMessages: [ChatMessage],
        remainingSystemPrompts: inout [String]
    ) async -> Bool {
        let llmMessages = chatHistoryService.expandMessagesForLLM(storageMessages)

        // 上下文裁剪：防止长时运行对话超出 token 限制
        let contextWindowSize = resolveContextWindowSize(for: conversationId)
        let lastInputTokens = resolveLastInputTokens(for: conversationId)
        let pruneResult = ContextPruner.prune(
            llmMessages,
            lastInputTokens: lastInputTokens,
            contextWindowSize: contextWindowSize
        )

        let result = await performLLMRequest(
            conversationId: conversationId,
            messages: pruneResult.messages,
            additionalSystemPrompts: remainingSystemPrompts
        )
        remainingSystemPrompts = []

        switch result {
        case let .success(assistantMessage):
            let processed = toolCallExecutor.evaluatePermissions(for: assistantMessage, conversationId: conversationId)
            conversationVM.saveMessage(processed, to: conversationId)
            return true

        case .cancelled:
            finishTurnByCancellation(conversationId: conversationId)
            runTurnFinishedPipeline(conversationId: conversationId, endReason: .cancelled)
            NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
            return false

        case let .failed(error):
            let providerId = currentProviderId(for: conversationId)
            finishTurnWithError(error, conversationId: conversationId, providerId: providerId)
            runTurnFinishedPipeline(conversationId: conversationId, endReason: .failed(error.localizedDescription))
            NotificationCenter.postAgentTurnFinished(conversationId: conversationId)
            return false
        }
    }

    /// 向 LLM 发送一次流式请求（含重试）。
    ///
    /// - Parameters:
    ///   - conversationId: 会话 ID
    ///   - messages: 发给 LLM 的消息列表
    ///   - additionalSystemPrompts: 临时系统提示词（不落库）
    /// - Returns: `.success(助手消息)` / `.cancelled` / `.failed(错误)`
    private func performLLMRequest(
        conversationId: UUID,
        messages: [ChatMessage],
        additionalSystemPrompts: [String] = []
    ) async -> LLMRequestResult {
        let messagesForLLM = Self.composeMessagesForLLM(
            conversationId: conversationId,
            baseMessages: messages,
            additionalSystemPrompts: additionalSystemPrompts
        )

        // 将语言偏好注入工具服务，使 tools 返回本地化后的描述
        toolService.languagePreference = projectVM.languagePreference

        let availableTools = ToolAvailabilityGuard().evaluate(
            tools: toolService.tools,
            allowsTools: agentSessionConfig.chatMode.allowsTools,
            isFinalStep: false
        )
        let toolsArg = availableTools.isEmpty ? nil : availableTools
        let config = resolveRequestConfig(
            conversationId: conversationId,
            messages: messagesForLLM,
            allowsTools: toolsArg != nil
        )

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
                AppLogger.core.info("\(Self.t)⚠️ 流式请求失败（第 \(attempt) 次），\(Int(delay)) 秒后重试：\(error.localizedDescription)")
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

        AppLogger.core.error("\(Self.t)请求模型最终失败：\(error.localizedDescription)")

        await Self.runPostPipeline(
            metadataHolder: metadataHolder,
            startTime: startTime,
            response: nil,
            error: error,
            middlewares: middlewares
        )

        return .failed(error)
    }
}

// MARK: - LLM 请求辅助

extension AgentTurnService {
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
    ) -> @Sendable (HTTPRequestMetadata) async -> Void {
        let statusVM = self.statusVM
        return { metadata in
            await metadataHolder.set(metadata)
            await MainActor.run {
                statusVM.setStatus(conversationId: conversationId, content: "正在发送消息，大小：\(metadata.formattedBodySize)")
            }
        }
    }

    private func resolveRequestConfig(conversationId: UUID, messages: [ChatMessage], allowsTools: Bool) -> LLMConfig {
        let fallback = conversationVM.resolveModelConfig(
            for: conversationId,
            fallbackConfigProvider: agentSessionConfig
        )
        guard agentSessionConfig.isAutoMode else {
            agentSessionConfig.lastAutoRouteSummary = nil
            return fallback
        }

        // 构建路由信号
        let signal = RouteSignal(
            hasImages: messages.contains { !$0.images.isEmpty },
            messageLength: messages.reduce(0) { $0 + $1.content.count },
            allowsTools: allowsTools,
            currentProviderId: fallback.providerId,
            currentModel: fallback.model
        )

        // 收集候选模型（App 层负责过滤：能力匹配、API Key、可用性）
        let candidates = collectRouteCandidates(signal: signal, allowsTools: allowsTools)

        // 调用 Package 进行评分决策
        let router = ModelRouter()
        guard let decision = router.route(candidates: candidates, signal: signal) else {
            agentSessionConfig.lastAutoRouteSummary = "Auto 未找到可用候选，已使用当前选择"
            return fallback
        }

        // 将决策结果转为 LLMConfig
        let apiKey = Self.apiKey(forProviderId: decision.providerId, llmService: llmService) ?? ""
        let config = LLMConfig(apiKey: apiKey, model: decision.model, providerId: decision.providerId)

        agentSessionConfig.lastAutoRouteSummary = "\(decision.providerDisplayName) · \(decision.model)（\(decision.reason)）"
        return config
    }

    /// 从所有已注册供应商中收集符合条件的候选模型
    private func collectRouteCandidates(signal: RouteSignal, allowsTools: Bool) -> [RouteCandidate] {
        let availabilityStore = LLMModelAvailabilityStore.shared

        return llmService.allProviders().flatMap { provider -> [RouteCandidate] in
            guard provider.isEnabled else { return [] }

            // 远程供应商必须有 API Key
            if !provider.isLocal,
               Self.apiKey(forProviderId: provider.id, llmService: llmService)?.isEmpty != false {
                return []
            }

            return provider.availableModels.compactMap { model -> RouteCandidate? in
                // 能力匹配检查
                guard Self.passesCapabilities(
                    provider: provider,
                    model: model,
                    hasImages: signal.hasImages,
                    allowsTools: allowsTools,
                    llmService: llmService
                ) else {
                    return nil
                }

                // 可用性检查
                let status = availabilityStore.status(providerId: provider.id, modelId: model)
                if case .unavailable = status { return nil }

                let candidateAvailability: CandidateAvailability
                switch status {
                case .available: candidateAvailability = .available
                case .checking:  candidateAvailability = .checking
                case .unknown, nil: candidateAvailability = .unknown
                case .unavailable: return nil
                }

                return RouteCandidate(
                    providerId: provider.id,
                    providerDisplayName: provider.displayName,
                    model: model,
                    availability: candidateAvailability,
                    contextWindowSizes: provider.contextWindowSizes
                )
            }
        }
    }

    /// 检查模型能力是否满足请求需求
    private static func passesCapabilities(
        provider: LLMProviderInfo,
        model: String,
        hasImages: Bool,
        allowsTools: Bool,
        llmService: LLMService
    ) -> Bool {
        if provider.isLocal { return true }

        guard let caps = llmService.providerType(forId: provider.id)?.modelCapabilities[model] else {
            return !hasImages && !allowsTools
        }
        if hasImages && !caps.supportsVision { return false }
        if allowsTools && !caps.supportsTools { return false }
        return true
    }

    /// 获取供应商的 API Key
    private static func apiKey(forProviderId providerId: String, llmService: LLMService) -> String? {
        guard let providerType = llmService.providerType(forId: providerId) else { return nil }
        return APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey)
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
            // 从 LLMServiceError.requestFailed 中提取 HTTP 状态码
            if let llmError = error as? LLMServiceError,
               case let .requestFailed(_, statusCode) = llmError {
                mutableMetadata.responseStatusCode = statusCode
            }
            // 兜底：如果是 HTTPClientError（某些路径可能直接抛出）
            else if let apiError = error as? HTTPClientError,
                    case let .httpError(statusCode, _) = apiError {
                mutableMetadata.responseStatusCode = statusCode
            }
        } else {
            mutableMetadata.responseStatusCode = 200
        }
        let pipeline = SendPipeline(middlewares: middlewares)
        await pipeline.runPost(metadata: mutableMetadata, response: response)
    }

    /// 获取当前会话的 providerId
    private func currentProviderId(for conversationId: UUID) -> String? {
        conversationVM.resolveModelConfig(
            for: conversationId,
            fallbackConfigProvider: agentSessionConfig
        ).providerId
    }

    // MARK: - 上下文裁剪辅助

    /// 获取当前会话使用的模型的上下文窗口大小
    private func resolveContextWindowSize(for conversationId: UUID) -> Int? {
        let config = conversationVM.resolveModelConfig(
            for: conversationId,
            fallbackConfigProvider: agentSessionConfig
        )
        return llmService.allProviders()
            .first(where: { $0.id == config.providerId })?
            .contextWindowSizes[config.model]
    }

    /// 从最近一条 assistant 消息中提取 inputTokens，用于自适应裁剪
    private func resolveLastInputTokens(for conversationId: UUID) -> Int? {
        guard let messages = chatHistoryService.loadMessages(forConversationId: conversationId) else {
            return nil
        }
        return messages.last(where: { $0.role == .assistant })?.inputTokens
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
    private static func isRetryable(_ error: Error) -> Bool {
        // ── LLMServiceError ──
        if let llmError = error as? LLMServiceError {
            switch llmError {
            case .requestFailed: return true
            case .cancelled:     return false
            default:             return false // 配置类错误不重试
            }
        }

        // ── HTTPClientError（由 LLMAPIService 直接抛出）──
        if let apiError = error as? HTTPClientError {
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

// MARK: - 回合收尾

extension AgentTurnService {
    /// 正常结束一轮对话。
    private func finishTurn(conversationId: UUID, emitCompletionEvent: Bool = true) {
        messageQueueVM.finishProcessing(for: conversationId)
        conversationSendStatusVM.clearStatus(conversationId: conversationId)
        if emitCompletionEvent {
            NotificationCenter.postAgentConversationSendTurnFinished(conversationId: conversationId)
        }
    }

    /// 因错误结束一轮对话：保存错误消息并结束。
    private func finishTurnWithError(
        _ error: Error,
        conversationId: UUID,
        providerId: String?
    ) {
        AppLogger.core.error("\(Self.t) 回合因错误终止：\(error.localizedDescription)")

        // 提取原始 HTTP 错误详情
        let rawDetail = Self.extractRawErrorDetail(from: error)

        var errorMessage: ChatMessage
        if let llmError = error as? LLMServiceError {
            errorMessage = llmError.toChatMessage(conversationId: conversationId, providerId: providerId)
            errorMessage.rawErrorDetail = rawDetail
        } else {
            errorMessage = ChatMessage(
                role: .assistant,
                conversationId: conversationId,
                content: error.localizedDescription,
                isError: true,
                rawErrorDetail: rawDetail
            )
        }

        conversationVM.saveMessage(errorMessage, to: conversationId)
        finishTurn(conversationId: conversationId)
    }

    /// 从 Error 中提取原始 HTTP 错误详情（状态码 + 响应体），用于 UI 折叠展示。
    private static func extractRawErrorDetail(from error: Error) -> String? {
        if let llmError = error as? LLMServiceError,
           case let .requestFailed(_, statusCode) = llmError,
           let statusCode {
            return "HTTP \(statusCode)"
        }
        if let apiError = error as? HTTPClientError,
           case let .httpError(statusCode, message) = apiError {
            return "HTTP \(statusCode)\n\(message)"
        }
        return nil
    }

    /// 因取消结束一轮对话。
    private func finishTurnByCancellation(conversationId: UUID) {
        conversationSendStatusVM.setStatus(conversationId: conversationId, content: "已停止生成")
        finishTurn(conversationId: conversationId, emitCompletionEvent: false)
    }

    /// 因用户拒绝工具执行结束一轮对话。
    private func finishTurnByUserRejection(conversationId: UUID) {
        conversationSendStatusVM.setStatus(
            conversationId: conversationId,
            content: "用户拒绝执行工具，已结束回合"
        )
        finishTurn(conversationId: conversationId)
    }

    // MARK: - Turn 结束后管线

    /// 运行 Turn 结束后管线
    ///
    /// 在 `finishTurn` 之后调用，按 `order` 顺序执行所有中间件的 `handleTurnFinished` 方法。
    /// 使用 `Task` 异步派发，不阻塞当前收尾流程。
    private func runTurnFinishedPipeline(
        conversationId: UUID,
        endReason: TurnEndReason
    ) {
        let middlewares = pluginVM.getSuperSendMiddlewares()
        let chatHistoryService = self.chatHistoryService
        let projectVM = self.projectVM
        let messageQueueVM = self.messageQueueVM
        let conversationVM = self.conversationVM

        Task {
            let turnMessages = chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
            let ctx = AppTurnFinishedContext(
                conversationId: conversationId,
                endReason: endReason,
                turnMessages: turnMessages,
                chatHistoryService: chatHistoryService,
                projectVM: projectVM,
                messageQueueVM: messageQueueVM,
                conversationVM: conversationVM
            )
            let pipeline = SendPipeline(middlewares: middlewares)
            await pipeline.runTurnFinished(ctx: ctx)
        }
    }
}
