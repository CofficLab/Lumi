import Foundation

/// 消息发送队列向外部报告的处理事件（由 `MessageSenderVM` 产出，Root + Handler 消费）。
@MainActor
enum MessageSendEvent: Sendable {
    case processingStarted(conversationId: UUID)
    case processingFinished(conversationId: UUID)
    case sendMessage(ChatMessage, conversationId: UUID)
}
