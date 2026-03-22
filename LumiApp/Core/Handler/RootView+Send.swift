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

    /// 流式请求模型并落库助手消息；若无工具调用则结束当前发送回合。
    /// - Parameters:
    ///   - ensuringIncludedMessage: 若历史列表中尚无该条（例如刚落库与读库时序），则追加后再请求模型。
    func send(
        conversationId: UUID,
        ensuringIncludedMessage: ChatMessage? = nil,
        config: LLMConfig,
        tools: [AgentTool]?,
        onChunk: @Sendable @escaping (StreamChunk) async -> Void,
        failureLogSummary: String
    ) async {
        var messages = await chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
        if let extra = ensuringIncludedMessage,
           !messages.contains(where: { $0.id == extra.id }) {
            messages.append(extra)
        }

        let statusVM = conversationSendStatusVM
        do {
            statusVM.setStatus(conversationId: conversationId, content: "正在发送消息…")
            let assistantMessage = try await llmService.sendStreamingMessage(
                messages: messages,
                config: config,
                tools: tools,
                onChunk: onChunk
            )
            await conversationVM.saveMessage(assistantMessage, to: conversationId)
            if assistantMessage.hasToolCalls == false {
                finishSendTurn(conversationId: conversationId)
            }
        } catch {
            AppLogger.core.error("\(Self.t) \(failureLogSummary)：\(error)")
            statusVM.setStatus(
                conversationId: conversationId,
                content: "发送失败：\(error.localizedDescription)"
            )
            finishSendTurn(conversationId: conversationId)
        }
    }

    /// 已落库的助手消息包含工具调用时：执行一轮工具 → 再请求一次模型（后续若仍有工具调用，由下一次 `messageSaved` 驱动）。
    func continueSendAfterToolCalls(
        assistantMessage: ChatMessage,
        conversationId: UUID
    ) async {
        guard messageQueueVM.currentProcessingIndex(for: conversationId) != nil else { return }
        guard let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty else { return }

        let statusVM = conversationSendStatusVM
        let convId = conversationId
        let logTag = Self.t

        let config = sessionConfig.getCurrentConfig()
        let availableTools = ToolAvailabilityGuard().evaluate(
            tools: toolService.tools,
            allowsTools: projectVM.chatMode.allowsTools,
            isFinalStep: false
        )
        let toolsArg = availableTools.isEmpty ? nil : availableTools

        let onStreamChunk: @Sendable (StreamChunk) async -> Void = { chunk in
            await MainActor.run {
                AppLogger.core.info("\(logTag) 收到响应，类型：\(chunk.eventType?.rawValue ?? "unknown")，内容：\(chunk.content ?? "")")
                statusVM.applyStreamChunk(conversationId: convId, chunk: chunk)
            }
        }

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

        await send(
            conversationId: conversationId,
            config: config,
            tools: toolsArg,
            onChunk: onStreamChunk,
            failureLogSummary: "工具后续请求模型失败"
        )
    }
}
