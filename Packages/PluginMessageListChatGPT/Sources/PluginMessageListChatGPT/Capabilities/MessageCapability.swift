import Foundation
import ProviderMessage

/// 消息读取所需的最小消息能力。
///
/// - Note: V5 只消费「分页取窗」这一条路径：
///   首屏、向上翻页与尾部刷新都由 `MessageListPaginationService` 统一走分页 API，
///   不需要整会话快照。
@MainActor
protocol MessageListMessageCapability: AnyObject {
    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message]
    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool
}

@MainActor
final class MessageListMessageCapabilityAdapter: MessageListMessageCapability {
    private let messages: any MessageManaging

    init(messages: any MessageManaging) {
        self.messages = messages
    }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        await messages.messagePageAsync(
            for: conversationID,
            limit: limit,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        )
    }

    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool {
        await messages.hasEarlierMessagesAsync(
            for: conversationID,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        )
    }
}
