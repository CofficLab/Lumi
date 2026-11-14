import Foundation
import ProviderConversationState

/// 会话活动状态所需的最小会话状态能力。
@MainActor
public protocol MessageListConversationStateCapability: AnyObject {
    func state(for conversationID: UUID) -> ConversationStateSnapshot
}

@MainActor
public final class MessageListConversationStateCapabilityAdapter: MessageListConversationStateCapability {
    private let conversationState: any ConversationStateProviding
    public init(conversationState: any ConversationStateProviding) { self.conversationState = conversationState }
    public func state(for conversationID: UUID) -> ConversationStateSnapshot {
        conversationState.state(for: conversationID)
    }
}