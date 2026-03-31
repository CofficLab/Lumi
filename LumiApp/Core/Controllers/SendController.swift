import Foundation
import MagicKit

/// 聊天发送与回合驱动控制器
///
/// 根据落库消息驱动「请求模型 → 工具执行」闭环，并与发送队列、状态栏联动。
/// 由 `RootView` 注入 `RootViewContainer` 使用。
///
/// ## 架构说明
/// - 内核不知道 RAG 等插件的内部服务
/// - 插件通过中间件机制参与消息发送流程
/// - 插件内部服务由插件自己管理
@MainActor
final class SendController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"

    /// 详细日志级别
    /// 0: 关闭日志
    /// 1: 基础日志
    /// 2: 详细日志（输出请求/响应的详细信息）
    nonisolated static let verbose = 2

    private let container: RootViewContainer
    private var activeSendTasksByConversation: [UUID: Task<Void, Never>] = [:]
    private var pendingTransientSystemPromptsByConversation: [UUID: [String]] = [:]

    init(container: RootViewContainer) {
        self.container = container
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
            AppLogger.core.info("\(Self.t) 启动一次发送链路：\n\(message.content.max(200))")
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

        if Self.verbose > 1 {
            AppLogger.core.info("\(Self.t) 发送上下文")
        }
        let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
        if Self.verbose > 1 {
            AppLogger.core.info("\(Self.t) 发送管道")
        }
        await pipeline.run(ctx: ctx) { _ in
            if Self.verbose > 1 {
                AppLogger.core.info("\(Self.t) 发送管道完成")
            }
        }
        pendingTransientSystemPromptsByConversation[conversationId] = ctx.transientSystemPrompts

        await send(conversationId: conversationId)
    }

    /// 根据会话中**已落库的最后一条消息**驱动后续步骤
    func send(conversationId: UUID) async {
        let messages = await container.chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
        guard !messages.isEmpty else { return }
        // 允许系统/状态消息插入到尾部，但不应中断发送闭环。
        // 这里选择“最后一条可驱动消息”（user/tool/assistant）作为状态机输入。
        guard let last = messages.last(where: { $0.role != .system && $0.role != .status }) else {
            if Self.verbose > 1 {
                AppLogger.core.info("\(Self.t) 没有可驱动消息")
            }
            return
        }

        switch last.role {
        case .user, .tool:
            guard container.messageQueueVM.isProcessing(for: conversationId) else { return }
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
        case .system, .status, .error:
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

    /// 使用当前会话配置与可用工具，对给定消息列表发起**一次**流式模型请求。
    /// 使用当前会话配置与可用工具，对给定消息列表发起**一次**流式模型请求。
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

        do {
            statusVM.setStatus(conversationId: conversationId, content: "正在发送消息…")

            let assistantMessage = try await container.llmService.sendStreamingMessage(
                messages: messagesForLLM,
                config: config,
                tools: toolsArg,
                onChunk: onStreamChunk,
                onRequestStart: { metadata in
                    // 线程安全地设置元数据
                    Task {
                        await metadataHolder.set(metadata)
                    }

                    Task { @MainActor in
                        statusVM.setStatus(conversationId: conversationId, content: "正在发送消息，大小：\(metadata.formattedBodySize)")
                    }
                }
            )

            // 计算耗时并调用后置管线（如果有元数据）
            if let metadata = await metadataHolder.get() {
                var mutableMetadata = metadata
                mutableMetadata.duration = CFAbsoluteTimeGetCurrent() - startTime
                let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
                await pipeline.runPost(metadata: mutableMetadata, response: assistantMessage)
            }

            await onMessageReceived(message: assistantMessage, conversationId: conversationId)
        } catch LLMServiceError.cancelled {
            AppLogger.core.info("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 发送已取消")
            finishSendTurn(conversationId: conversationId, emitCompletionEvent: false)
            statusVM.setStatus(conversationId: conversationId, content: "已停止生成")

            // 取消时调用后置管线（如果有元数据）
            if let metadata = await metadataHolder.get() {
                var mutableMetadata = metadata
                mutableMetadata.error = LLMServiceError.cancelled
                mutableMetadata.duration = CFAbsoluteTimeGetCurrent() - startTime
                let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
                await pipeline.runPost(metadata: mutableMetadata, response: nil)
            }

        } catch {
            AppLogger.core.error("\(Self.t) 请求模型失败：\(error)")
            finishSendTurn(conversationId: conversationId)

            // 失败时调用后置管线（如果有元数据）
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
                errorMessage = llmError.toChatMessage(conversationId: conversationId)
            } else {
                // 其他错误类型，创建通用的错误消息
                errorMessage = ChatMessage(
                    role: .assistant,
                    conversationId: conversationId,
                    content: error.localizedDescription,
                    isError: true
                )
            }
            container.conversationVM.saveMessage(errorMessage, to: conversationId)
        }
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

        for toolCall in toolCalls {
            statusVM.setStatus(
                conversationId: conversationId,
                content: "正在执行工具：\(toolCall.name)…"
            )

            // 执行工具
            let resultMsg: ChatMessage
            do {
                let result = try await container.toolExecutionService.executeTool(toolCall)
                resultMsg = ChatMessage(
                    role: .tool,
                    conversationId: conversationId,
                    content: result,
                    toolCallID: toolCall.id
                )
            } catch {
                resultMsg = container.toolExecutionService.createErrorMessage(for: toolCall, error: error, conversationId: conversationId)
            }

            container.conversationVM.saveMessage(resultMsg, to: conversationId)
        }
    }
}
