import Foundation

/// Serializes message-tail refreshes and collapses an event burst into at most
/// one active refresh plus one trailing refresh.
///
/// `run` is main-actor isolated because its caller publishes SwiftUI state.
/// While the active operation is suspended on I/O, overlapping callers only
/// mark a trailing pass as required and return without spawning more work.
@MainActor
final class MessageListTailRefreshGate {
    private var isRunning = false
    private var needsTrailingRefresh = false

    /// Runs `operation` until no request arrived during its last suspended pass.
    ///
    /// Only the caller that owns the active run can receive `true`. Overlapping
    /// callers return `false`, preventing duplicate post-refresh scroll actions.
    func run(_ operation: @escaping @MainActor () async -> Bool) async -> Bool {
        guard !isRunning else {
            needsTrailingRefresh = true
            return false
        }

        isRunning = true
        defer {
            isRunning = false
            needsTrailingRefresh = false
        }

        var didChange = false
        repeat {
            needsTrailingRefresh = false
            didChange = await operation() || didChange
        } while needsTrailingRefresh

        return didChange
    }
}

enum MessageListNotificationFilter {
    /// Events without a conversation ID are treated as legacy global events.
    static func shouldHandle(
        eventConversationID: UUID?,
        selectedConversationID: UUID?
    ) -> Bool {
        guard let selectedConversationID else { return false }
        guard let eventConversationID else { return true }
        return eventConversationID == selectedConversationID
    }
}
