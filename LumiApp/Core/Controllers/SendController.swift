import Foundation
import MagicKit

/// 聊天发送与回合驱动控制器
@MainActor
final class SendController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"

    /// 详细日志级别
    /// 0: 关闭日志
    /// 1: 基础日志
    /// 2: 详细日志（输出请求/响应的详细信息）
    nonisolated static let verbose = 0

    private let container: RootViewContainer
    private let chatService: ChatHistoryService
    private var activeSendTasksByConversation: [UUID: Task<Void, Never>] = [:]
    private var pendingTransientSystemPromptsByConversation: [UUID: [String]] = [:]

    init(container: RootViewContainer) {
        self.container = container
        self.chatService = container.chatHistoryService
    }

    /// 尝试从队列中出队一条"可处理"的消息并开始发送。
    /// 当某个对话在 `processingMessages` 中已有消息进行处理时，该对话的待发送消息不会被出队。
    func attemptBeginNextQueuedSend() async {
        guard let message = container.messageQueueVM.dequeueNextEligibleMessage() else { return }
        let conversationId = message.conversationId

        // 如果该会话已有活跃任务，将消息状态改回 pending，避免卡住
        guard activeSendTasksByConversation[conversationId] == nil else {
            container.messageQueueVM.requeueMessage(message)
            return
        }

        activeSendTasksByConversation[conversationId] = Task { [weak self] in
            guard let self = self else { return }
            await self.beginSendFromQueue(conversationId: conversationId, message: message)
            await MainActor.run {
                self.activeSendTasksByConversation[conversationId] = nil
            }
        }
    }

    /// 取消某个会话当前发送任务，并清理处理中状态。
    func cancelSend(conversationId: UUID) {
        let shouldPersistCancelMessage = activeSendTasksByConversation[conversationId] != nil
        activeSendTasksByConversation[conversationId]?.cancel()
        activeSendTasksByConversation[conversationId] = nil

        if container.permissionRequestVM.pendingToolPermissionSession?.conversationId == conversationId {
            container.permissionRequestVM.setPendingPermissionRequest(nil)
            container.permissionRequestVM.setPendingToolPermissionSession(nil)
        }

        finishSendTurn(conversationId: conversationId, emitCompletionEvent: false)
        container.conversationSendStatusVM.setStatus(conversationId: conversationId, content: "已停止生成")

        // 用户主动取消后，补一条系统消息落库（不参与 LLM 上下文）。
        guard shouldPersistCancelMessage else { return }
        let systemMessage = ChatMessage(role: .system, conversationId: conversationId, content: "用户主动取消了对话")
        container.conversationVM.saveMessage(systemMessage, to: conversationId)
    }

    /// 结束当前「发送队列」对应的一轮处理。
    func finishSendTurn(conversationId: UUID, emitCompletionEvent: Bool = true) {
        container.messageQueueVM.finishProcessing(for: conversationId)
        container.conversationSendStatusVM.clearStatus(conversationId: conversationId)
        if emitCompletionEvent {
            NotificationCenter.postAgentConversationSendTurnFinished(conversationId: conversationId)
        }
    }

    /// 从队列入口启动一次发送链路：投影 UI、落库、运行发送中间件，然后继续 `send`。
    func beginSendFromQueue(conversationId: UUID, message: ChatMessage) async {
        if Self.verbose >= 1 {
            AppLogger.core.info("\(Self.t) [\(conversationId)] 启动一次发送链路：\n\(message.content.max(200))")
        }

        if container.conversationVM.selectedConversationId == conversationId {
            container.messagePendingVM.appendMessage(message)
        }

        container.conversationVM.saveMessage(message, to: conversationId)

        // 创建发送上下文
        let ctx = SendMessageContext(
            conversationId: conversationId,
            message: message,
            chatHistoryService: container.chatHistoryService,
            agentSessionConfig: container.agentSessionConfig,
            projectVM: container.projectVM
        )
        ctx.abortTurn = { [weak self] in
            self?.finishSendTurn(conversationId: conversationId, emitCompletionEvent: true)
            self?.container.conversationSendStatusVM.setStatus(
                conversationId: conversationId,
                content: "检测到异常，已终止"
            )
        }

        let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
        await pipeline.run(ctx: ctx) { _ in
            if Self.verbose > 1 {
                AppLogger.core.info("\(Self.t) 发送管道完成")
            }
        }
        pendingTransientSystemPromptsByConversation[conversationId] = ctx.transientSystemPrompts

        await send(conversationId: conversationId)
    }

    /// 根据会话中已落库的最后一条消息驱动后续步骤
    func send(conversationId: UUID) async {
        let messages = self.chatService.loadMessages(forConversationId: conversationId) ?? []
        guard !messages.isEmpty else {
            AppLogger.core.error("\(Self.t) [\(conversationId)] 处理已落库的最后一条消息，但无消息")
            return
        }
        // 允许系统/状态消息插入到尾部，但不应中断发送闭环。
        // 这里选择"最后一条可驱动消息"（user/tool/assistant）作为状态机输入。
        guard let last = messages.last(where: { $0.role != .system && $0.role != .status }) else {
            if Self.verbose > 1 {
                AppLogger.core.info("\(Self.t) 没有可驱动消息")
            }
            return
        }

        switch last.role {
        case .user, .tool:
            guard container.messageQueueVM.isProcessing(for: conversationId) else {
                if Self.verbose > 1 {
                    AppLogger.core.info("\(Self.t) 没有处理中消息")
                }
                return
            }
            let additionalSystemPrompts: [String]
            if last.role == .user {
                additionalSystemPrompts = consumeTransientSystemPrompts(for: conversationId)
            } else {
                additionalSystemPrompts = []
            }
            await streamAssistantReply(
                conversationId: conversationId,
                messages: messages,
                additionalSystemPrompts: additionalSystemPrompts
            )
        case .assistant:
            if last.hasToolCalls {
                guard container.messageQueueVM.isProcessing(for: conversationId) else { return }
                if await presentToolPermissionIfNeeded(assistantMessage: last, conversationId: conversationId) {
                    return
                }
                let hadUserRejection = last.toolCalls?.contains { $0.authorizationState == .userRejected } ?? false
                await executeToolCalls(assistantMessage: last, conversationId: conversationId)
                if hadUserRejection {
                    finishSendTurn(conversationId: conversationId)
                    await MainActor.run {
                        container.conversationSendStatusVM.setStatus(
                            conversationId: conversationId,
                            content: "用户拒绝执行工具，已结束回合"
                        )
                    }
                    return
                }
                await send(conversationId: conversationId)
            } else if container.messageQueueVM.isProcessing(for: conversationId) {
                finishSendTurn(conversationId: conversationId)
            }
        case .system, .status, .error, .unknown:
            break
        }
    }

    func onMessageReceived(message: ChatMessage, conversationId: UUID) async {
        if Self.verbose >= 2 {
            AppLogger.core.info("\(Self.t) 收到消息：\(message.content.max(50))")
        }

        var message = message

        if var calls = message.toolCalls {
            for i in calls.indices {
                let risk = await container.toolExecutionService.evaluateRisk(
                    toolName: calls[i].name,
                    arguments: calls[i].arguments
                )

                if Self.verbose >= 2 {
                    AppLogger.core.info("\(Self.t)🔨 工具名称：\(calls[i].name)")
                    AppLogger.core.info("\(Self.t)    参数：\(calls[i].arguments.max(50))")
                    AppLogger.core.info("\(Self.t)    风险：\(risk.displayName)")
                }

                if !risk.requiresPermission {
                    calls[i].authorizationState = .noRisk
                } else if container.projectVM.autoApproveRisk {
                    calls[i].authorizationState = .autoApproved
                } else {
                    calls[i].authorizationState = .pendingAuthorization
                }
            }
            message.toolCalls = calls
        }

        container.conversationVM.saveMessage(message, to: conversationId)

        if message.hasToolCalls {
            await send(conversationId: conversationId)
        } else {
            finishSendTurn(conversationId: conversationId)
        }
    }

    /// 若存在仍待授权的工具调用，则填充 `PermissionRequestVM` 并返回 `true`（发送管线应暂停）。
    private func presentToolPermissionIfNeeded(assistantMessage: ChatMessage, conversationId: UUID) async -> Bool {
        guard let calls = assistantMessage.toolCalls,
              let firstPending = calls.first(where: { $0.authorizationState.needsAuthorizationPrompt }) else {
            return false
        }

        let risk = await container.toolExecutionService.evaluateRisk(
            toolName: firstPending.name,
            arguments: firstPending.arguments
        )
        let request = PermissionRequest(
            toolName: firstPending.name,
            argumentsString: firstPending.arguments,
            toolCallID: firstPending.id,
            riskLevel: risk
        )

        await MainActor.run {
            container.permissionRequestVM.setPendingPermissionRequest(request)
            container.permissionRequestVM.setPendingToolPermissionSession(
                PendingToolPermissionSession(
                    conversationId: conversationId,
                    assistantMessageId: assistantMessage.id
                )
            )
            container.conversationSendStatusVM.setStatus(
                conversationId: conversationId,
                content: "等待工具授权：\(firstPending.name)…"
            )
        }
        return true
    }

    // MARK: - 流式请求重试配置

    /// 流式请求最大重试次数
    private nonisolated let maxStreamRetries: Int = 3

    /// 流式请求重试初始等待时间（秒）
    private nonisolated let streamRetryBaseDelay: Double = 2.0

    /// 流式请求重试退避倍数
    private nonisolated let streamRetryBackoffMultiplier: Double = 2.0

    /// 使用当前会话配置与可用工具，对给定消息列表发起流式模型请求。
    ///
    /// 内建重试机制：遇到可重试的瞬时错误（网络超时、5xx 服务端错误、429 速率限制等）时，
    /// 自动按指数退避重试，最多 `maxStreamRetries` 次。取消操作不重试。
    private func streamAssistantReply(
        conversationId: UUID,
        messages: [ChatMessage],
        additionalSystemPrompts: [String] = []
    ) async {
        let messagesForLLM = composeMessagesForLLM(
            conversationId: conversationId,
            baseMessages: messages,
            additionalSystemPrompts: additionalSystemPrompts
        )
        let config = container.agentSessionConfig.getCurrentConfig()
        let availableTools = ToolAvailabilityGuard().evaluate(
            tools: container.toolService.tools,
            allowsTools: container.agentSessionConfig.chatMode.allowsTools,
            isFinalStep: false
        )
        let toolsArg = availableTools.isEmpty ? nil : availableTools

        let statusVM = container.conversationSendStatusVM
        let convId = conversationId
        let onStreamChunk: @Sendable (StreamChunk) async -> Void = { chunk in
            await MainActor.run {
                statusVM.applyStreamChunk(conversationId: convId, chunk: chunk)
            }
        }

        // 记录开始时间
        let startTime = CFAbsoluteTimeGetCurrent()

        // 使用线程安全的 MetadataHolder
        let metadataHolder = MetadataHolder()

        // ── 重试循环 ──────────────────────────────────────────
        var lastError: Error?

        for attempt in 1 ... maxStreamRetries {
            // 检查取消
            if Task.isCancelled {
                finishSendTurn(conversationId: conversationId, emitCompletionEvent: false)
                statusVM.setStatus(conversationId: conversationId, content: "已停止生成")
                return
            }

            do {
                if attempt == 1 {
                    statusVM.setStatus(conversationId: conversationId, content: "正在发送消息…")
                } else {
                    statusVM.setStatus(conversationId: conversationId, content: "正在重试 (\(attempt)/\(maxStreamRetries))…")
                }

                let assistantMessage = try await container.llmService.sendStreamingMessage(
                    messages: messagesForLLM,
                    config: config,
                    tools: toolsArg,
                    onChunk: onStreamChunk,
                    onRequestStart: { metadata in
                        Task {
                            await metadataHolder.set(metadata)
                        }

                        Task { @MainActor in
                            statusVM.setStatus(conversationId: conversationId, content: "正在发送消息，大小：\(metadata.formattedBodySize)")
                        }
                    }
                )

                // ✅ 成功 → 计算耗时并调用后置管线
                if let metadata = await metadataHolder.get() {
                    var mutableMetadata = metadata
                    mutableMetadata.duration = CFAbsoluteTimeGetCurrent() - startTime
                    let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
                    await pipeline.runPost(metadata: mutableMetadata, response: assistantMessage)
                }

                await onMessageReceived(message: assistantMessage, conversationId: conversationId)
                return // 成功，退出重试循环

            } catch LLMServiceError.cancelled {
                // 取消不重试
                AppLogger.core.info("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 发送已取消")
                finishSendTurn(conversationId: conversationId, emitCompletionEvent: false)
                statusVM.setStatus(conversationId: conversationId, content: "已停止生成")

                if let metadata = await metadataHolder.get() {
                    var mutableMetadata = metadata
                    mutableMetadata.error = LLMServiceError.cancelled
                    mutableMetadata.duration = CFAbsoluteTimeGetCurrent() - startTime
                    let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
                    await pipeline.runPost(metadata: mutableMetadata, response: nil)
                }
                return

            } catch {
                lastError = error

                // 判断是否可重试
                guard attempt < maxStreamRetries, isRetryableStreamError(error) else {
                    break // 不可重试或重试耗尽，跳出循环
                }

                // 计算退避延迟
                let delay = calculateStreamRetryDelay(for: attempt)
                AppLogger.core.info("\(Self.t) ⚠️ 流式请求失败（第 \(attempt) 次），\(Int(delay)) 秒后重试：\(error.localizedDescription)")
                statusVM.setStatus(conversationId: conversationId, content: "请求失败，\(Int(delay)) 秒后重试 (\(attempt + 1)/\(maxStreamRetries))…")

                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    // sleep 被取消，直接退出
                    finishSendTurn(conversationId: conversationId, emitCompletionEvent: false)
                    return
                }
            }
        }

        // ── 重试耗尽或不可重试的错误 → 记录并结束 ──────────
        guard let error = lastError else { return }

        AppLogger.core.error("\(Self.t) 请求模型最终失败：\(error.localizedDescription)")
        finishSendTurn(conversationId: conversationId)

        // 失败时调用后置管线
        if let metadata = await metadataHolder.get() {
            var mutableMetadata = metadata
            mutableMetadata.error = error
            mutableMetadata.duration = CFAbsoluteTimeGetCurrent() - startTime
            if let apiError = error as? APIError,
               case let .httpError(statusCode, _) = apiError {
                mutableMetadata.responseStatusCode = statusCode
            }
            let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
            await pipeline.runPost(metadata: mutableMetadata, response: nil)
        }

        // 保存错误消息到数据库
        let errorMessage: ChatMessage
        if let llmError = error as? LLMServiceError {
            errorMessage = llmError.toChatMessage(conversationId: conversationId, providerId: config.providerId)
        } else {
            errorMessage = ChatMessage(
                role: .assistant,
                conversationId: conversationId,
                content: error.localizedDescription,
                isError: true
            )
        }
        container.conversationVM.saveMessage(errorMessage, to: conversationId)
    }

    // MARK: - 流式请求重试辅助

    /// 判断流式请求遇到的错误是否可重试。
    ///
    /// 可重试：网络超时、网络断开、5xx 服务端错误、429 速率限制。
    /// 不可重试：配置错误（API Key 为空等）、用户取消、客户端 4xx 错误。
    private func isRetryableStreamError(_ error: Error) -> Bool {
        // LLMServiceError 中只有 requestFailed 可能是瞬时网络/API 错误
        if let llmError = error as? LLMServiceError {
            switch llmError {
            case .requestFailed:
                return true
            case .cancelled:
                return false
            default:
                // 配置类错误（apiKeyEmpty、modelEmpty 等）不重试
                return false
            }
        }

        // APIError（来自 HTTP 层）
        if let apiError = error as? APIError {
            switch apiError {
            case let .httpError(statusCode, _):
                // 429 速率限制：重试
                if statusCode == 429 { return true }
                // 5xx 服务端错误：重试
                if (500 ... 599).contains(statusCode) { return true }
                // 其他 4xx 客户端错误：不重试
                return false
            case .requestFailed:
                // 底层网络错误（超时、断开等）：重试
                return true
            default:
                return false
            }
        }

        // 其他未知错误：保守不重试
        return false
    }

    /// 计算流式请求重试的退避延迟（指数退避 + 随机抖动）
    private func calculateStreamRetryDelay(for attempt: Int) -> Double {
        let delay = streamRetryBaseDelay * pow(streamRetryBackoffMultiplier, Double(attempt - 1))
        let jitter = Double.random(in: 0 ... 1.0)
        return delay + jitter
    }

    private func consumeTransientSystemPrompts(for conversationId: UUID) -> [String] {
        let prompts = pendingTransientSystemPromptsByConversation[conversationId] ?? []
        pendingTransientSystemPromptsByConversation[conversationId] = nil
        return prompts
    }

    private func composeMessagesForLLM(
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

    /// 执行某条助手消息中声明的全部工具调用，并将每条结果以 `role: .tool` 消息落库。
    private func executeToolCalls(assistantMessage: ChatMessage, conversationId: UUID) async {
        guard let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty else { return }

        let statusVM = container.conversationSendStatusVM
        let totalCount = toolCalls.count

        for (index, toolCall) in toolCalls.enumerated() {
            if Task.isCancelled {
                statusVM.applyToolProgressEvent(conversationId: conversationId, event: .cancelledAll)
                break
            }

            let step = index + 1
            let startedAt = Date()
            let initialShellStats = await Self.shellStats(for: toolCall.name)
            statusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .running(
                    toolName: toolCall.name,
                    current: step,
                    total: totalCount,
                    elapsedSeconds: 0,
                    shellStats: initialShellStats
                )
            )

            let progressTask = Task { [weak statusVM] in
                while !Task.isCancelled {
                    let elapsed = Int(Date().timeIntervalSince(startedAt))
                    let shellStats = await Self.shellStats(for: toolCall.name)
                    await MainActor.run {
                        statusVM?.applyToolProgressEvent(
                            conversationId: conversationId,
                            event: .running(
                                toolName: toolCall.name,
                                current: step,
                                total: totalCount,
                                elapsedSeconds: elapsed,
                                shellStats: shellStats
                            )
                        )
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }

            // 执行工具
            let resultMsg: ChatMessage
            do {
                let result = try await withTaskCancellationHandler {
                    try await container.toolExecutionService.executeTool(toolCall)
                } onCancel: {
                    progressTask.cancel()
                }
                progressTask.cancel()
                resultMsg = ChatMessage(
                    role: .tool,
                    conversationId: conversationId,
                    content: result,
                    toolCallID: toolCall.id
                )
                statusVM.applyToolProgressEvent(
                    conversationId: conversationId,
                    event: .completed(toolName: toolCall.name, current: step, total: totalCount)
                )
            } catch is CancellationError {
                progressTask.cancel()
                statusVM.applyToolProgressEvent(
                    conversationId: conversationId,
                    event: .cancelled(toolName: toolCall.name, current: step, total: totalCount)
                )
                break
            } catch {
                progressTask.cancel()
                resultMsg = container.toolExecutionService.createErrorMessage(for: toolCall, error: error, conversationId: conversationId)
                statusVM.applyToolProgressEvent(
                    conversationId: conversationId,
                    event: .failed(
                        toolName: toolCall.name,
                        current: step,
                        total: totalCount,
                        errorSummary: Self.errorSummary(from: error)
                    )
                )
            }

            container.conversationVM.saveMessage(resultMsg, to: conversationId)
        }
    }

    private static func errorSummary(from error: Error) -> String {
        error.localizedDescription
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知错误"
    }

    private static func shellStats(for toolName: String) async -> ToolProgressShellStats? {
        guard toolName == "run_command",
              let snapshot = await ShellService.shared.progressSnapshot() else {
            return nil
        }
        return ToolProgressShellStats(
            totalLines: snapshot.totalLines,
            totalBytes: snapshot.totalBytes,
            latestOutputPreview: snapshot.latestOutputPreview
        )
    }
}
