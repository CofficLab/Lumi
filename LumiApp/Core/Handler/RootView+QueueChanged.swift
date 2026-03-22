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
            // 投影到当前消息列表（仅当该会话仍处于选中状态）
            if self.conversationVM.selectedConversationId == conversationId {
                self.messageViewModel.appendMessage(message)
            }

            // 落库保存
            await self.conversationVM.saveMessage(message, to: conversationId)

            // 中间件系统
            let ctx = SendMessageContext(conversationId: conversationId, message: message)
            let all: [SendMiddleware] = []
            let pipeline = SendPipeline(middlewares: all)
            await pipeline.run(ctx: ctx) { _ in }

            await self.send(conversationId: conversationId)
        }
    }
}
