import Foundation
import Testing
@testable import PluginConversationList

@Test @MainActor func attentionStorePublishesOnlyStateChanges() {
    let store = ConversationAttentionStore()
    let conversationID = UUID()
    var received: [AttentionSnapshot] = []
    let handle = store.addObserver { event in
        guard case .attentionChanged(let id, let needsAttention) = event else { return }
        received.append(AttentionSnapshot(id: id, needsAttention: needsAttention))
    }

    #expect(!store.needsAttention(for: conversationID))
    store.markRead(conversationID: conversationID)
    store.markNeedsAttention(conversationID: conversationID)
    store.markNeedsAttention(conversationID: conversationID)
    #expect(store.needsAttention(for: conversationID))
    store.markRead(conversationID: conversationID)
    store.markRead(conversationID: conversationID)

    #expect(!store.needsAttention(for: conversationID))
    #expect(received == [
        AttentionSnapshot(id: conversationID, needsAttention: true),
        AttentionSnapshot(id: conversationID, needsAttention: false),
    ])

    handle.cancel()
    handle.cancel()
    store.markNeedsAttention(conversationID: conversationID)
    #expect(received.count == 2)
}

@Test @MainActor func attentionIsTrackedIndependentlyForEachConversation() {
    let store = ConversationAttentionStore()
    let firstID = UUID()
    let secondID = UUID()
    store.markNeedsAttention(conversationID: firstID)
    store.markNeedsAttention(conversationID: secondID)

    store.markRead(conversationID: firstID)

    #expect(!store.needsAttention(for: firstID))
    #expect(store.needsAttention(for: secondID))
}

private struct AttentionSnapshot: Equatable {
    let id: UUID
    let needsAttention: Bool
}
