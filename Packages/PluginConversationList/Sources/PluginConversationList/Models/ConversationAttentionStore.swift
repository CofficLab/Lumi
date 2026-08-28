import Combine
import Foundation

/// Tracks conversations whose agent turn finished while they were not selected.
@MainActor
public final class ConversationAttentionStore: ObservableObject {
    @Published private(set) var conversationIDs: Set<UUID> = []

    public init() {}

    public func markNeedsAttention(conversationID: UUID) {
        conversationIDs.insert(conversationID)
    }

    public func markRead(conversationID: UUID) {
        conversationIDs.remove(conversationID)
    }

    public func needsAttention(for conversationID: UUID) -> Bool {
        conversationIDs.contains(conversationID)
    }
}
