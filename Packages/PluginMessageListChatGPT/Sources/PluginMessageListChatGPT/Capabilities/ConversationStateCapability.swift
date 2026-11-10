import Foundation
import ProviderConversationState

/// 会话活动状态所需的最小会话状态能力。
@MainActor
protocol MessageListConversationStateCapability: AnyObject {
    func state(for conversationID: UUID) -> ConversationStateSnapshot
}

@MainActor
final class MessageListConversationStateCapabilityAdapter: MessageListConversationStateCapability {
    private let conversationState: any ConversationStateProviding

    init(conversationState: any ConversationStateProviding) {
        self.conversationState = conversationState
    }

    func state(for conversationID: UUID) -> ConversationStateSnapshot {
        conversationState.state(for: conversationID)
    }
}
