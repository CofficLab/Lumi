import Foundation
import ProviderConversation

/// 会话列表所需的最小会话能力。
@MainActor
public protocol MessageListConversationCapability: AnyObject {
    var selectedConversationID: UUID? { get }
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity
}

@MainActor
public final class MessageListConversationCapabilityAdapter: MessageListConversationCapability {
    private let conversations: any ConversationManaging
    public init(conversations: any ConversationManaging) { self.conversations = conversations }
    public var selectedConversationID: UUID? { conversations.selectedConversationID }
    public func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        conversations.verbosity(for: conversationID)
    }
}