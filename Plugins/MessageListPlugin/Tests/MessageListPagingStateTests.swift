import Foundation
import Testing
@testable import MessageListPlugin

@Suite
struct MessageListPagingStateTests {
    @Test
    func followsLatestByDefaultAndResetsOnConversationChange() {
        var state = MessageListPagingState()

        #expect(state.shouldAutoRefreshLatestOnMessageChange)

        state.didLoadEarlierPage(firstMessageID: UUID())
        #expect(!state.shouldAutoRefreshLatestOnMessageChange)

        state.resetForConversationChange()
        #expect(state.shouldAutoRefreshLatestOnMessageChange)
        #expect(state.oldestVisibleMessageID == nil)
    }

    @Test
    func loadingLatestPageRestoresAutoRefreshAndTracksAnchor() {
        var state = MessageListPagingState()
        let anchor = UUID()

        state.didLoadEarlierPage(firstMessageID: UUID())
        state.didLoadLatestPage(firstMessageID: anchor)

        #expect(state.shouldAutoRefreshLatestOnMessageChange)
        #expect(state.oldestVisibleMessageID == anchor)
    }
}
