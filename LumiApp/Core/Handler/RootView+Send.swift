import Foundation
import MagicKit
import SwiftUI

extension RootView {
    /// 发送队列：取出待发送消息 → 投影/落库 → 流式 LLM（含工具多轮）→ 完成后出队。
    func onSend() {
        if Self.verbose {
            AppLogger.core.info("\(Self.t) 发送消息")
        }

        guard let conversationId = self.conversationVM.selectedConversationId else {
            AppLogger.core.error("\(Self.t) 当前没有选中的会话")
            return
        }

        let pendingMessages = self.messageQueueVM.pendingMessages(for: conversationId)
        guard let message = pendingMessages.first else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 当前会话没有待发送消息")
            }
            return
        }

        self.messageQueueVM.setCurrentProcessingIndex(0, for: conversationId)

        Task { @MainActor in
            // 投影到当前消息列表（仅当该会话仍处于选中状态）
            if self.conversationVM.selectedConversationId == conversationId {
                self.messageViewModel.appendMessage(message)
            }

            // 落库保存
            await self.conversationVM.saveMessage(message, to: conversationId)

            // 补充历史消息（与 `runTurnJob` 一致）
            var messagesForLLM = await self.chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
            if !messagesForLLM.contains(where: { $0.id == message.id }) {
                messagesForLLM.append(message)
            }

            let ctx = SendMessageContext(conversationId: conversationId, message: message)

            let all: [SendMiddleware] = []
            let pipeline = SendPipeline(middlewares: all)
            await pipeline.run(ctx: ctx) { _ in }

            let config = self.sessionConfig.getCurrentConfig()
            let availableTools = ToolAvailabilityGuard().evaluate(
                tools: self.toolService.tools,
                allowsTools: self.projectVM.chatMode.allowsTools,
                isFinalStep: false
            )
            let toolsArg = availableTools.isEmpty ? nil : availableTools

            let onStreamChunk: @Sendable (StreamChunk) async -> Void = { chunk in
                AppLogger.core.info("\(Self.t) 收到响应，类型：\(chunk.eventType?.rawValue ?? "unknown")，内容：\(chunk.content ?? "")")
            }

            do {
                var assistantMessage = try await self.llmService.sendStreamingMessage(
                    messages: messagesForLLM,
                    config: config,
                    tools: toolsArg,
                    onChunk: onStreamChunk
                )

                await self.conversationVM.saveMessage(assistantMessage, to: conversationId)

                var followUpDepth = 0
                while let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty {
                    guard followUpDepth < AgentConfig.maxDepth else {
                        AppLogger.core.error("\(Self.t) 工具后续轮次超过 maxDepth，停止")
                        break
                    }
                    followUpDepth += 1

                    for toolCall in toolCalls {
                        let requiresPermission = self.toolExecutionService.requiresPermission(
                            toolName: toolCall.name,
                            arguments: toolCall.arguments
                        )
                        let riskLevel = self.toolExecutionService.evaluateRisk(
                            toolName: toolCall.name,
                            arguments: toolCall.arguments
                        )
                        let permissionResult = ToolPermissionGuard().evaluate(
                            toolCall: toolCall,
                            autoApproveRisk: self.projectVM.autoApproveRisk,
                            requiresPermission: requiresPermission,
                            riskLevel: riskLevel
                        )

                        let resultMsg: ChatMessage
                        switch permissionResult {
                        case .permissionRequired:
                            resultMsg = ChatMessage.makeAbortMessage(toolCallID: toolCall.id)
                            AppLogger.core.warning("\(Self.t) 工具 \(toolCall.name) 需要权限确认，简化发送链路下已中止该调用")
                        case .proceed:
                            do {
                                let result = try await self.toolExecutionService.executeTool(toolCall)
                                resultMsg = ChatMessage(
                                    role: .tool,
                                    content: result,
                                    toolCallID: toolCall.id
                                )
                            } catch {
                                resultMsg = self.toolExecutionService.createErrorMessage(for: toolCall, error: error)
                            }
                        }

                        await self.conversationVM.saveMessage(resultMsg, to: conversationId)
                    }

                    let nextMessages = await self.chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
                    assistantMessage = try await self.llmService.sendStreamingMessage(
                        messages: nextMessages,
                        config: config,
                        tools: toolsArg,
                        onChunk: onStreamChunk
                    )

                    await self.conversationVM.saveMessage(assistantMessage, to: conversationId)
                }
            } catch {
                AppLogger.core.error("\(Self.t) 发送消息失败：\(error)")
            }

            self.messageQueueVM.removeFirstMessage(for: conversationId)
            self.messageQueueVM.setCurrentProcessingIndex(nil, for: conversationId)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)✅ [\(String(conversationId.uuidString.prefix(8)))] 消息发送完成，已从队列移除")
            }
        }
    }
}
