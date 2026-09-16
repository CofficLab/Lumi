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
