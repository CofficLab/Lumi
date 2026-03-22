import Foundation
import MagicKit
import SwiftUI

extension RootView {
    /// 结束当前发送回合：出队、清理处理中状态。
    func finishSendTurn(conversationId: UUID) {
        messageQueueVM.removeFirstMessage(for: conversationId)
        messageQueueVM.setCurrentProcessingIndex(nil, for: conversationId)
        conversationSendStatusVM.clearStatus(conversationId: conversationId)
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ [\(String(conversationId.uuidString.prefix(8)))] 消息发送完成，已从队列移除")
        }
    }

    /// 根据会话**最后一条**落库消息决定下一步：用户或工具结果 → 请求模型；助手且含工具调用 → 执行工具后再进入本方法。
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
            let assistantMessage = try await llmService.sendStreamingMessage(
                messages: messages,
                config: config,
                tools: toolsArg,
                onChunk: onStreamChunk
            )
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

    private func executeAssistantToolCalls(assistantMessage: ChatMessage, conversationId: UUID) async {
        guard let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty else { return }

        let statusVM = conversationSendStatusVM

        statusVM.setStatus(
            conversationId: conversationId,
            content: "准备执行 \(toolCalls.count) 个工具…"
        )

        let someToolNeedsPermission = toolCalls.contains {
            toolExecutionService.requiresPermission(
                toolName: $0.name,
                arguments: $0.arguments
            )
        }
        let userConsentedToToolUse =
            projectVM.autoApproveRisk || assistantMessage.userApprovedToolCalls

        if someToolNeedsPermission && !userConsentedToToolUse {
            for toolCall in toolCalls {
                let resultMsg = ChatMessage.makeAbortMessage(toolCallID: toolCall.id)
                AppLogger.core.warning(
                    "\(Self.t) 工具 \(toolCall.name) 未获得用户同意执行需确认的工具调用，已跳过"
                )
                await conversationVM.saveMessage(resultMsg, to: conversationId)
            }
            statusVM.setStatus(
                conversationId: conversationId,
                content: "执行工具前需要你的同意：请确认本条助手消息的工具权限，或在标题栏开启自动批准"
            )
        } else {
            for toolCall in toolCalls {
                let requiresPermission = toolExecutionService.requiresPermission(
                    toolName: toolCall.name,
                    arguments: toolCall.arguments
                )
                let riskLevel = toolExecutionService.evaluateRisk(
                    toolName: toolCall.name,
                    arguments: toolCall.arguments
                )
                let permissionResult = ToolPermissionGuard().evaluate(
                    toolCall: toolCall,
                    autoApproveRisk: projectVM.autoApproveRisk
                        || assistantMessage.userApprovedToolCalls,
                    requiresPermission: requiresPermission,
                    riskLevel: riskLevel
                )

                let resultMsg: ChatMessage
                switch permissionResult {
                case .permissionRequired:
                    resultMsg = ChatMessage.makeAbortMessage(toolCallID: toolCall.id)
                    AppLogger.core.warning("\(Self.t) 工具 \(toolCall.name) 需要权限确认，简化发送链路下已中止该调用")
                    statusVM.setStatus(
                        conversationId: conversationId,
                        content: "工具「\(toolCall.name)」需要权限确认，已跳过"
                    )
                case .proceed:
                    statusVM.setStatus(
                        conversationId: conversationId,
                        content: "正在执行工具：\(toolCall.name)…"
                    )
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
                }

                await conversationVM.saveMessage(resultMsg, to: conversationId)
                statusVM.setStatus(
                    conversationId: conversationId,
                    content: "工具「\(toolCall.name)」已结束，写入结果"
                )
            }
        }
    }
}
