import Foundation

/// 对话轮次处理过程中产生的事件。
enum ConversationTurnEvent: Sendable {
    case responseReceived(ChatMessage, conversationId: UUID)
    case streamChunk(content: String, messageId: UUID, conversationId: UUID)
    case streamEvent(eventType: StreamEventType, content: String, rawEvent: String, messageId: UUID, conversationId: UUID)
    case streamStarted(messageId: UUID, conversationId: UUID)
    case streamFinished(message: ChatMessage, conversationId: UUID)
    case toolResultReceived(ChatMessage, conversationId: UUID)
    case permissionRequested(PermissionRequest, conversationId: UUID)
    case permissionDecision(allowed: Bool, request: PermissionRequest, conversationId: UUID)
    case maxDepthReached(currentDepth: Int, maxDepth: Int, conversationId: UUID)
    case completed(conversationId: UUID)
    case error(Error, conversationId: UUID)
    case shouldContinue(depth: Int, conversationId: UUID)
}
