import Foundation
import MagicKit

/// 聊天发送与回合驱动控制器
///
/// 根据落库消息驱动「请求模型 → 工具执行」闭环，并与发送队列、状态栏联动。
/// 由 `RootView` 注入 `RootViewContainer` 使用。
@MainActor
final class SendController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"

    /// 详细日志级别
    /// 0: 关闭日志
    /// 1: 基础日志
    /// 2: 详细日志（输出请求/响应的详细信息）
    nonisolated static let verbose = 1

    private let container: RootViewContainer
    private var activeSendTasksByConversation: [UUID: Task<Void, Never>] = [:]

    init(container: RootViewContainer) {
        self.container = container
    }

    /// 尝试从队列中出队一条"可处理"的消息并开始发送。
    /// 当某个对话在 `processingMessages` 中已有消息在处理时，该对话的待发送消息不会被出队。
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
        Task { @MainActor in
            await container.conversationVM.saveMessage(systemMessage, to: conversationId)
        }
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
            AppLogger.core.info("\(Self.t) 启动一次发送链路：\(message.content)")
        }

        if container.conversationVM.selectedConversationId == conversationId {
            container.messagePendingVM.appendMessage(message)
        }

        await container.conversationVM.saveMessage(message, to: conversationId)

        let ctx = SendMessageContext(conversationId: conversationId, message: message)
        let pipeline = SendPipeline(middlewares: container.pluginVM.getSendMiddlewares())
        await pipeline.run(ctx: ctx) { _ in }

        await send(conversationId: conversationId)
    }

    /// 根据会话中**已落库的最后一条消息**驱动后续步骤
    func send(conversationId: UUID) async {
        let messages = await container.chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
        guard let last = messages.last else { return }

        switch last.role {
        case .user, .tool:
            guard container.messageQueueVM.isProcessing(for: conversationId) else { return }
            await streamAssistantReply(conversationId: conversationId, messages: messages)
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
        case .system, .status:
            break
        }
    }

    func onMessageReceived(message: ChatMessage, conversationId: UUID) async {
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
                } else if container.ProjectVM.autoApproveRisk {
                    calls[i].authorizationState = .autoApproved
                } else {
                    calls[i].authorizationState = .pendingAuthorization
                }
            }
            message.toolCalls = calls
        }

        await container.conversationVM.saveMessage(message, to: conversationId)

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
    private func streamAssistantReply(conversationId: UUID, messages: [ChatMessage]) async {
        let config = container.agentSessionConfig.getCurrentConfig()
        let availableTools = ToolAvailabilityGuard().evaluate(
            tools: container.toolService.tools,
            allowsTools: container.ProjectVM.chatMode.allowsTools,
            isFinalStep: false
        )
        let toolsArg = availableTools.isEmpty ? nil : availableTools

        let statusVM = container.conversationSendStatusVM
        let convId = conversationId
        let onStreamChunk: @Sendable (StreamChunk) async -> Void = { chunk in
            await MainActor.run {
                statusVM.applyStreamChunk(conversationId: convId, chunk: chunk)
                if Self.verbose >= 2 {
                    AppLogger.core.info("\(Self.t) 事件：\(chunk.eventType?.rawValue ?? "unknown")，内容：\(chunk.content ?? "")，原始：\(chunk.rawStreamPayload?.max(200) ?? "")")
                }
            }
        }

        do {
            statusVM.setStatus(conversationId: conversationId, content: "正在发送消息…")
            let assistantMessage = try await container.llmService.sendStreamingMessage(
                messages: messages,
                config: config,
                tools: toolsArg,
                onChunk: onStreamChunk
            )
            await onMessageReceived(message: assistantMessage, conversationId: conversationId)
        } catch LLMServiceError.cancelled {
            AppLogger.core.info("\(Self.t) [\(String(conversationId.uuidString.prefix(8)))] 发送已取消")
            finishSendTurn(conversationId: conversationId, emitCompletionEvent: false)
            statusVM.setStatus(conversationId: conversationId, content: "已停止生成")
        } catch {
            AppLogger.core.error("\(Self.t) 请求模型失败：\(error)")
            finishSendTurn(conversationId: conversationId)
            statusVM.setStatus(
                conversationId: conversationId,
                content: error.localizedDescription
            )
        }
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

            await container.conversationVM.saveMessage(resultMsg, to: conversationId)
        }
    }
}