import Foundation
import ProviderMessage

/// 消息读取所需的最小消息能力。
@MainActor
public protocol MessageListMessageCapability: AnyObject {
    func messagesSnapshot(in conversationID: UUID) async -> [Message]
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
public final class MessageListMessageCapabilityAdapter: MessageListMessageCapability {
    private let messages: any MessageManaging
    public init(messages: any MessageManaging) { self.messages = messages }
    public func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        await messages.messagesSnapshot(in: conversationID)
    }
    public func messagePageAsync(
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
    public func hasEarlierMessagesAsync(
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