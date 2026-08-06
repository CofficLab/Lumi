import Foundation
import LumiKernel

/// Immutable snapshot of the native message list for one conversation.
///
/// The coordinator builds a snapshot off the main actor, then hands it to the
/// controller for diffing against the previous one. Snapshots are `Sendable`
/// and `Equatable` so refresh gating can cheaply detect "nothing changed".
public struct AppKitMessageListSnapshot: Equatable, Sendable {
    public let conversationID: UUID?
    /// Stable history rows (persisted messages + synthesized rows), in
    /// display order. Does not contain the live streaming tail.
    public let rows: [AppKitMessageRow]
    /// Live streaming tail (V2 only). Kept separate so token updates never
    /// rebuild `rows`.
    public let streamingRow: AppKitMessageRow?
    /// Whether an earlier page exists above the current window.
    public let hasEarlierRows: Bool
    /// Initial-load state (conversation switch in progress).
    public let isLoading: Bool
    /// True while the current conversation is being streamed or sent.
    public let isLive: Bool

    public init(
        conversationID: UUID?,
        rows: [AppKitMessageRow],
        streamingRow: AppKitMessageRow? = nil,
        hasEarlierRows: Bool = false,
        isLoading: Bool = false,
        isLive: Bool = false
    ) {
        self.conversationID = conversationID
        self.rows = rows
        self.streamingRow = streamingRow
        self.hasEarlierRows = hasEarlierRows
        self.isLoading = isLoading
        self.isLive = isLive
    }

    /// Rows in final display order (history + live tail).
    public var displayRows: [AppKitMessageRow] {
        guard let streamingRow else { return rows }
        return rows + [streamingRow]
    }

    /// Empty state is based on real persisted history — a live status/streaming
    /// row alone does not count as content.
    public var isEmpty: Bool {
        rows.isEmpty && streamingRow == nil
    }

    public static let empty = AppKitMessageListSnapshot(
        conversationID: nil,
        rows: [],
        isLoading: false
    )

    public static func loading(conversationID: UUID?) -> AppKitMessageListSnapshot {
        AppKitMessageListSnapshot(
            conversationID: conversationID,
            rows: [],
            isLoading: true
        )
    }
}
