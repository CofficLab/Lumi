import Foundation
import MagicKit
import SwiftUI

extension RootView {
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

        Task {
            await self.sendMessagePipeline(
                message: message,
                conversationId: conversationId,
                messageViewModel: container.messageViewModel,
                conversationVM: container.conversationVM,
                runtimeStore: container.conversationRuntimeStore,
                sessionConfig: container.agentSessionConfig,
                projectVM: container.ProjectVM,
                slashCommandService: container.slashCommandService
            )

            await MainActor.run {
                self.messageQueueVM.removeFirstMessage(for: conversationId)
                self.messageQueueVM.setCurrentProcessingIndex(nil, for: conversationId)
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)✅ [\(String(conversationId.uuidString.prefix(8)))] 消息发送完成，已从队列移除")
                }
            }
        }
    }

    /// 消息发送
    @MainActor
    private func sendMessagePipeline(
        message: ChatMessage,
        conversationId: UUID,
        messageViewModel: MessagePendingVM,
        conversationVM: ConversationVM,
        runtimeStore: ConversationRuntimeStore,
        sessionConfig: AgentSessionConfig,
        projectVM: ProjectVM,
        slashCommandService: SlashCommandService
    ) async {
        // 投影到当前消息列表（仅当该会话仍处于选中状态）
        if self.conversationVM.selectedConversationId == conversationId {
            self.messageViewModel.appendMessage(message)
        }

        // 落库保存
        await self.conversationVM.saveMessage(message, to: conversationId)

        // 补充历史消息
        var messagesForLLM = await self.chatHistoryService.loadMessagesAsync(forConversationId: conversationId) ?? []
        if !messagesForLLM.contains(where: { $0.id == message.id }) {
            messagesForLLM.append(message)
        }

        // 生成上下文
        let ctx = SendMessageContext(conversationId: conversationId, message: message)

        // 加载中间件
//        let pluginRows = PluginVM.shared.getMessageSendMiddlewares()

//        let slashMiddleware = AnySendMiddleware(SlashCommandMiddleware())
//        let coreSendMiddleware = AnyMessageSendMiddleware(CoreSendMiddleware())
//        let all = [slashMiddleware] + pluginRows + [coreSendMiddleware]
//        let all = [slashMiddleware] + pluginRows + [coreSendMiddleware]
        let all: [SendMiddleware] = [
        ]

        let pipeline = SendPipeline(middlewares: all)

        await pipeline.run(ctx: ctx) { _ in
            // no-op
        }

        // 发送消息
        do {
            let responseMessage = try await self.llmService.sendStreamingMessage(
                messages: messagesForLLM,
                config: self.sessionConfig.getCurrentConfig(),
                tools: self.toolService.tools,
                onChunk: { chunk in
                AppLogger.core.info("\(Self.t) 收到流式响应，事件类型：\(chunk.eventType?.rawValue ?? "unknown")，内容：\(chunk.content ?? "")")

            })

            // 落库保存
            await self.conversationVM.saveMessage(responseMessage, to: conversationId)
        } catch {
            AppLogger.core.error("\(Self.t) 发送消息失败：\(error)")
        }
    }
}
