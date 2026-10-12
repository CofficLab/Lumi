import Foundation
import ProviderMessage
import Testing
@testable import ProviderMessageStreaming

@Test @MainActor func streamingLifecycleAccumulatesContentAndReasoningAndNotifiesChanges() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()
    var events: [MessageStreamingChange] = []
    let observer = streaming.addMessageStreamingObserver { events.append($0) }

    #expect(streaming.stage(for: conversationID) == .idle)
    #expect(streaming.streamingMessage(for: conversationID) == nil)

    streaming.start(conversationID: conversationID)
    #expect(streaming.stage(for: conversationID) == .sending)
    #expect(streaming.streamingMessage(for: conversationID)?.role == .assistant)
    #expect(streaming.streamingMessage(for: conversationID)?.content == "")

    streaming.appendContent("Hello", conversationID: conversationID)
    streaming.appendContent(" world", conversationID: conversationID)
    #expect(streaming.stage(for: conversationID) == .generating)
    #expect(streaming.streamingMessage(for: conversationID)?.content == "Hello world")

    streaming.appendThinking("Reason", conversationID: conversationID)
    streaming.appendThinking("ing", conversationID: conversationID)
    #expect(streaming.stage(for: conversationID) == .thinking)
    #expect(streaming.streamingMessage(for: conversationID)?.reasoningContent == "Reasoning")
    #expect(streaming.streamingMessage(for: conversationID)?.content == "Hello world")

    streaming.end(conversationID: conversationID)
    #expect(streaming.stage(for: conversationID) == .idle)
    #expect(streaming.streamingMessage(for: conversationID) == nil)
    #expect(events == Array(repeating: .updated(conversationID), count: 6))

    observer.cancel()
    streaming.start(conversationID: conversationID)
    #expect(events.count == 6)
}

@Test @MainActor func streamingStateIsIsolatedByConversation() {
    let streaming = DefaultMessageStreamingProviding()
    let firstID = UUID()
    let secondID = UUID()

    streaming.start(conversationID: firstID)
    streaming.appendContent("First", conversationID: firstID)
    streaming.start(conversationID: secondID)
    streaming.appendThinking("Second reasoning", conversationID: secondID)

    #expect(streaming.stage(for: firstID) == .generating)
    #expect(streaming.streamingMessage(for: firstID)?.content == "First")
    #expect(streaming.streamingMessage(for: firstID)?.reasoningContent == nil)
    #expect(streaming.stage(for: secondID) == .thinking)
    #expect(streaming.streamingMessage(for: secondID)?.content == "")
    #expect(streaming.streamingMessage(for: secondID)?.reasoningContent == "Second reasoning")
}

@Test @MainActor func appendingChunksWithoutAnActiveMessageDoesNothing() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()
    var events: [MessageStreamingChange] = []
    let observer = streaming.addMessageStreamingObserver { events.append($0) }

    streaming.appendContent("ignored", conversationID: conversationID)
    streaming.appendThinking("ignored", conversationID: conversationID)

    #expect(streaming.stage(for: conversationID) == .idle)
    #expect(streaming.streamingMessage(for: conversationID) == nil)
    #expect(events.isEmpty)
    observer.cancel()
}

@Test @MainActor func streamingStageRawValuesMatchExpectedStrings() {
    #expect(MessageStreamingStage.idle.rawValue == "idle")
    #expect(MessageStreamingStage.sending.rawValue == "sending")
    #expect(MessageStreamingStage.thinking.rawValue == "thinking")
    #expect(MessageStreamingStage.generating.rawValue == "generating")
}

@Test @MainActor func streamingChangeEqualityIsBasedOnConversationID() {
    let id = UUID()
    #expect(MessageStreamingChange.updated(id) == .updated(id))
    #expect(MessageStreamingChange.updated(id) != .updated(UUID()))
}

@Test @MainActor func startAfterEndCreatesAFreshEmptyMessage() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()

    streaming.start(conversationID: conversationID)
    streaming.appendContent("old", conversationID: conversationID)
    streaming.end(conversationID: conversationID)

    streaming.start(conversationID: conversationID)
    #expect(streaming.stage(for: conversationID) == .sending)
    #expect(streaming.streamingMessage(for: conversationID)?.content == "")
    #expect(streaming.streamingMessage(for: conversationID)?.reasoningContent == nil)
}

@Test @MainActor func startOverwritesAnInProgressMessage() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()

    streaming.start(conversationID: conversationID)
    streaming.appendContent("partial", conversationID: conversationID)
    #expect(streaming.streamingMessage(for: conversationID)?.content == "partial")

    // Restarting mid-stream resets the row to an empty assistant message.
    streaming.start(conversationID: conversationID)
    #expect(streaming.stage(for: conversationID) == .sending)
    #expect(streaming.streamingMessage(for: conversationID)?.content == "")
    #expect(streaming.streamingMessage(for: conversationID)?.reasoningContent == nil)
}

@Test @MainActor func endOnAnUnknownConversationNotifiesButLeavesStateIdle() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()
    var events: [MessageStreamingChange] = []
    let observer = streaming.addMessageStreamingObserver { events.append($0) }

    streaming.end(conversationID: conversationID)

    #expect(streaming.stage(for: conversationID) == .idle)
    #expect(streaming.streamingMessage(for: conversationID) == nil)
    // end() always notifies, even for an unknown conversation.
    #expect(events == [.updated(conversationID)])
    observer.cancel()
}

@Test @MainActor func multipleObserversAllReceiveTheSameChange() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()
    var first: [MessageStreamingChange] = []
    var second: [MessageStreamingChange] = []
    let h1 = streaming.addMessageStreamingObserver { first.append($0) }
    let h2 = streaming.addMessageStreamingObserver { second.append($0) }

    streaming.start(conversationID: conversationID)

    #expect(first == [.updated(conversationID)])
    #expect(second == [.updated(conversationID)])
    h1.cancel()
    h2.cancel()
}

@Test @MainActor func observerChangeCarriesTheAffectedConversationID() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()
    var seenIDs: [UUID] = []
    let observer = streaming.addMessageStreamingObserver { change in
        guard case .updated(let id) = change else { return }
        seenIDs.append(id)
    }

    streaming.start(conversationID: conversationID)
    streaming.appendContent("hi", conversationID: conversationID)
    streaming.end(conversationID: conversationID)

    #expect(seenIDs == [conversationID, conversationID, conversationID])
    observer.cancel()
}

@Test @MainActor func doubleCancelIsSafeAndDoesNotAffectOtherObservers() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()
    var otherCount = 0
    let dropped = streaming.addMessageStreamingObserver { _ in }
    let keep = streaming.addMessageStreamingObserver { _ in otherCount += 1 }

    dropped.cancel()
    dropped.cancel()

    streaming.start(conversationID: conversationID)
    #expect(otherCount == 1)
    keep.cancel()
}

@Test @MainActor func appendThinkingOnAFreshMessageInitializesReasoningFromNil() {
    let streaming = DefaultMessageStreamingProviding()
    let conversationID = UUID()

    streaming.start(conversationID: conversationID)
    #expect(streaming.streamingMessage(for: conversationID)?.reasoningContent == nil)

    streaming.appendThinking("thought", conversationID: conversationID)
    #expect(streaming.streamingMessage(for: conversationID)?.reasoningContent == "thought")
}
