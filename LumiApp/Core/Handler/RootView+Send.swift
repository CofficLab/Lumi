import Foundation
import MagicKit
import SwiftUI

// MARK: - 发送与会话回合

/// 聊天发送相关逻辑：根据落库消息驱动「请求模型 → 工具执行」闭环，并与发送队列、状态栏联动。
extension RootView {
    /// 结束当前「发送队列」对应的一轮处理。
    ///
    /// 从队列移除队首消息、清除正在处理索引，并清空该会话的发送状态文案。
    ///
    /// - Parameter conversationId: 目标会话 ID。
    func finishSendTurn(conversationId: UUID) {
        messageQueueVM.removeFirstMessage(for: conversationId)
        messageQueueVM.setCurrentProcessingIndex(nil, for: conversationId)
        conversationSendStatusVM.clearStatus(conversationId: conversationId)
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ [\(String(conversationId.uuidString.prefix(8)))] 消息发送完成，已从队列移除")
        }
    }

    /// 根据会话中**已落库的最后一条消息**驱动后续步骤。
    ///
    /// 仅在 `messageQueueVM` 对该会话存在「正在处理」索引时，才会发起模型请求或执行工具（避免误触发）。
    ///
    /// 分支概要：
    /// - 最后一条为 **用户** 或 **工具结果**：拉取完整历史，流式请求模型并落库助手消息；若助手含工具调用则递归进入本方法以执行工具。
    /// - 最后一条为 **助手** 且含工具调用：若有 `pendingAuthorization` 则设置权限 VM 并**返回**等待用户；全部非 pending 后再执行工具并落库，随后递归进入本方法。
    /// - 最后一条为 **助手** 且无工具调用：若仍在处理中则视为回合结束，调用 `finishSendTurn`。
    /// - **系统 / 状态** 类消息：不处理。
    ///
    /// - Parameter conversationId: 目标会话 ID。
    func send(conversationId: UUID) async {
        let messages = await chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
        guard let last = messages.last else { return }

        switch last.role {
        case .user, .tool:
            guard messageQueueVM.currentProcessingIndex(for: conversationId) != nil else { return }
            await streamAssistantReply(conversationId: conversationId, messages: messages)
        case .assistant:
            if last.hasToolCalls {
                guard messageQueueVM.currentProcessingIndex(for: conversationId) != nil else { return }
                if await presentToolPermissionIfNeeded(assistantMessage: last, conversationId: conversationId) {
                    return
                }
                await executeAssistantToolCalls(assistantMessage: last, conversationId: conversationId)
                await send(conversationId: conversationId)
            } else if messageQueueVM.currentProcessingIndex(for: conversationId) != nil {
                finishSendTurn(conversationId: conversationId)
            }
        case .system, .status:
            break
        }
    }

    // MARK: - Private

    /// 若存在仍待授权的工具调用，则填充 `PermissionRequestVM` 并返回 `true`（发送管线应暂停）。
    private func presentToolPermissionIfNeeded(assistantMessage: ChatMessage, conversationId: UUID) async -> Bool {
        guard let calls = assistantMessage.toolCalls,
              let firstPending = calls.first(where: { $0.authorizationState.needsAuthorizationPrompt }) else {
            return false
        }

        let risk = toolExecutionService.evaluateRisk(
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
            permissionRequestViewModel.setPendingPermissionRequest(request)
            permissionRequestViewModel.setPendingToolPermissionSession(
                PendingToolPermissionSession(
                    conversationId: conversationId,
                    assistantMessageId: assistantMessage.id
                )
            )
            conversationSendStatusVM.setStatus(
                conversationId: conversationId,
                content: "等待工具授权：\(firstPending.name)…"
            )
        }
        return true
    }

    /// 使用当前会话配置与可用工具，对给定消息列表发起**一次**流式模型请求。
    ///
    /// 成功后将助手消息落库：若包含工具调用则 `await send(conversationId:)` 继续链路，否则结束回合。
    /// 失败时写入错误状态、记录日志并 `finishSendTurn`。
    ///
    /// - Parameters:
    ///   - conversationId: 目标会话 ID。
    ///   - messages: 已组装好的、将传给模型的完整上下文（须与落库顺序一致）。
    private func streamAssistantReply(conversationId: UUID, messages: [ChatMessage]) async {
        let config = sessionConfig.getCurrentConfig()
        let availableTools = ToolAvailabilityGuard().evaluate(
            tools: toolService.tools,
            allowsTools: projectVM.chatMode.allowsTools,
            isFinalStep: false
        )
        let toolsArg = availableTools.isEmpty ? nil : availableTools

        let statusVM = conversationSendStatusVM
        let convId = conversationId
        let logTag = Self.t
        let onStreamChunk: @Sendable (StreamChunk) async -> Void = { chunk in
            await MainActor.run {
                statusVM.applyStreamChunk(conversationId: convId, chunk: chunk)
                AppLogger.core.info("\(logTag) 收到响应，类型：\(chunk.eventType?.rawValue ?? "unknown")，内容：\(chunk.content ?? "")")
            }
        }

        do {
            statusVM.setStatus(conversationId: conversationId, content: "正在发送消息…")
            var assistantMessage = try await llmService.sendStreamingMessage(
                messages: messages,
                config: config,
                tools: toolsArg,
                onChunk: onStreamChunk
            )
            if projectVM.autoApproveRisk, var calls = assistantMessage.toolCalls {
                for i in calls.indices {
                    calls[i].authorizationState = .autoApproved
                }
                assistantMessage.toolCalls = calls
            }
            await conversationVM.saveMessage(assistantMessage, to: conversationId)
            if assistantMessage.hasToolCalls {
                await send(conversationId: conversationId)
            } else {
                finishSendTurn(conversationId: conversationId)
            }
        } catch {
            AppLogger.core.error("\(Self.t) 请求模型失败：\(error)")
            statusVM.setStatus(
                conversationId: conversationId,
                content: "发送失败：\(error.localizedDescription)"
            )
            finishSendTurn(conversationId: conversationId)
        }
    }

    /// 执行某条助手消息中声明的**全部**工具调用，并将每条结果以 `role: .tool` 消息落库。
    ///
    /// 不经过权限或同意校验；执行失败时写入错误内容。本方法**不**请求模型，调用方应在落库完成后通过 `send(conversationId:)` 继续。
    ///
    /// - Parameters:
    ///   - assistantMessage: 含非空 `toolCalls` 的助手消息。
    ///   - conversationId: 目标会话 ID。
    private func executeAssistantToolCalls(assistantMessage: ChatMessage, conversationId: UUID) async {
        guard let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty else { return }

        let statusVM = conversationSendStatusVM

        for toolCall in toolCalls {
            statusVM.setStatus(
                conversationId: conversationId,
                content: "正在执行工具：\(toolCall.name)…"
            )
            let resultMsg: ChatMessage
            do {
                let result = try await toolExecutionService.executeTool(toolCall)
                resultMsg = ChatMessage(
                    role: .tool,
                    content: result,
                    toolCallID: toolCall.id
                )
            } catch {
                resultMsg = toolExecutionService.createErrorMessage(for: toolCall, error: error)
            }

            await conversationVM.saveMessage(resultMsg, to: conversationId)
        }
    }
}
