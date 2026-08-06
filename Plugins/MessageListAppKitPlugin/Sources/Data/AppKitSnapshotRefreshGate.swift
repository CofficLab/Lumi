import Foundation

/// Serializes snapshot refreshes and collapses an event burst into at most
/// one active refresh plus one trailing refresh.
///
/// Aligned with the SwiftUI `MessageListTailRefreshGate`: while the active
/// operation is suspended on I/O, overlapping callers only mark a trailing pass
/// as required and return without spawning more work.
@MainActor
public final class AppKitSnapshotRefreshGate {
    private var isRunning = false
    private var needsTrailingRefresh = false

    public init() {}

    /// Runs `operation` until no request arrived during its last suspended pass.
    ///
    /// Only the caller that owns the active run receives `true`. Overlapping
    /// callers return `false`, preventing duplicate post-refresh actions.
    public func run(_ operation: @escaping @MainActor () async -> Bool) async -> Bool {
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

/// Filters message/turn notifications to the selected conversation.
public enum AppKitMessageNotificationFilter {
    /// Events without a conversation ID are treated as legacy global events
    /// and handled for the selected conversation.
    public static func shouldHandle(
        eventConversationID: UUID?,
        selectedConversationID: UUID?
    ) -> Bool {
        guard let selectedConversationID else { return false }
        guard let eventConversationID else { return true }
        return eventConversationID == selectedConversationID
    }
}
