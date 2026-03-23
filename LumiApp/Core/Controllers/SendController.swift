import Foundation
import MagicKit

/// 聊天发送与回合驱动控制器
///
/// 根据落库消息驱动「请求模型 → 工具执行」闭环，并与发送队列、状态栏联动。
/// 由 `RootView` 注入 `RootViewContainer` 使用。
@MainActor
final class SendController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    private let container: RootViewContainer

    init(container: RootViewContainer) {
        self.container = container
    }

    /// 尝试从队列中出队一条“可处理”的消息并开始发送。
    /// 当某个对话在 `processingMessages` 中已有消息在处理时，该对话的待发送消息不会被出队。
    func attemptBeginNextQueuedSend() async {
        guard let message = container.messageQueueVM.dequeueNextEligibleMessage() else { return }
        await beginSendFromQueue(conversationId: message.conversationId, message: message)
    }

    /// 结束当前「发送队列」对应的一轮处理。
    func finishSendTurn(conversationId: UUID) {
        container.messageQueueVM.finishProcessing(for: conversationId)
        container.conversationSendStatusVM.clearStatus(conversationId: conversationId)
        NotificationCenter.postAgentConversationSendTurnFinished(conversationId: conversationId)
    }

    /// 从队列入口启动一次发送链路：投影 UI、落库、运行发送中间件，然后继续 `send`。
    func beginSendFromQueue(conversationId: UUID, message: ChatMessage) async {
        if Self.verbose {
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

                if Self.verbose {
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
        let logTag = Self.t
        let onStreamChunk: @Sendable (StreamChunk) async -> Void = { chunk in
            await MainActor.run {
                statusVM.applyStreamChunk(conversationId: convId, chunk: chunk)
                AppLogger.core.info("\(logTag) 事件：\(chunk.eventType?.rawValue ?? "unknown")，内容：\(chunk.content ?? "")，原始：\(chunk.rawStreamPayload ?? "")")
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
