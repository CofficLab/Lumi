import Foundation
import Testing
@testable import PluginConversationContextSize

@Test func tokenFormatting() async throws {
    #expect(1000.formattedTokensShort == "1K")
    #expect(1500.formattedTokensShort == "2K")
    #expect(128000.formattedContextSize == "128K")
    #expect(1000000.formattedContextSize == "1M")
}

@Test @MainActor func contextSizeToolbarStateForwardsTypedEvents() {
    let state = ContextSizeToolbarState()
    let conversationID = UUID()
    var eventCount = 0
    let handle = state.addObserver { _ in eventCount += 1 }

    state.setSelectedConversationID(conversationID)
    state.markMessagesChanged(conversationID: conversationID)
    state.markLLMChanged()

    #expect(eventCount == 3)
    handle.cancel()
    state.markLLMChanged()
    #expect(eventCount == 3)
}
