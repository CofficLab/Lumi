import Foundation
import MagicKit
import SwiftUI

extension RootView {
    /// 发送队列：取出待发送消息 → 投影/落库 → **单次**流式 LLM
    func onQueueChanged() {
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

        Task {
            let statusVM = self.conversationSendStatusVM
            let convId = conversationId
            let logTag = Self.t

            // 投影到当前消息列表（仅当该会话仍处于选中状态）
            if self.conversationVM.selectedConversationId == conversationId {
                self.messageViewModel.appendMessage(message)
            }

            // 落库保存
            await self.conversationVM.saveMessage(message, to: conversationId)

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
                await MainActor.run {
                    statusVM.applyStreamChunk(conversationId: convId, chunk: chunk)
                    AppLogger.core.info("\(logTag) 收到响应，类型：\(chunk.eventType?.rawValue ?? "unknown")，内容：\(chunk.content ?? "")")
                }
            }

            await self.send(
                conversationId: conversationId,
                ensuringIncludedMessage: message,
                config: config,
                tools: toolsArg,
                onChunk: onStreamChunk,
                failureLogSummary: "发送消息失败"
            )
        }
    }
}
