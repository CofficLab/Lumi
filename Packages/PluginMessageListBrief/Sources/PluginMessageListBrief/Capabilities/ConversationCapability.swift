import Foundation
import ProviderConversation

/// 会话列表所需的最小会话能力。
@MainActor
protocol MessageListConversationCapability: AnyObject {
    var selectedConversationID: UUID? { get }
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity
}

@MainActor
final class MessageListConversationCapabilityAdapter: MessageListConversationCapability {
    private let conversations: any ConversationManaging

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    var selectedConversationID: UUID? { conversations.selectedConversationID }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        conversations.verbosity(for: conversationID)
    }
}
