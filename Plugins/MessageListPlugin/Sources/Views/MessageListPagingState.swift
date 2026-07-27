import Foundation

/// Tracks whether the message list should keep following the latest page.
///
/// When the user loads earlier messages, we stop auto-refreshing back to the
/// latest page so incoming messages don't yank the scroll position away.
struct MessageListPagingState {
    private(set) var oldestVisibleMessageID: UUID?
    private(set) var followsLatestMessages = true

    mutating func resetForConversationChange() {
        oldestVisibleMessageID = nil
        followsLatestMessages = true
    }

    mutating func didLoadLatestPage(firstMessageID: UUID?) {
        oldestVisibleMessageID = firstMessageID
        followsLatestMessages = true
    }

    mutating func didLoadEarlierPage(firstMessageID: UUID?) {
        oldestVisibleMessageID = firstMessageID
        followsLatestMessages = false
    }

    var shouldAutoRefreshLatestOnMessageChange: Bool {
        followsLatestMessages
    }
}
