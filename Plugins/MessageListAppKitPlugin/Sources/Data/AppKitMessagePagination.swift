import Foundation
import LumiKernel

/// Message window management for the native message list.
///
/// Behavior is aligned 1:1 with the SwiftUI `MessageListPaginationService`:
/// first-page load with earlier-message probing, cursor-based prepend, tail
/// refresh with overlap merge, and tail eviction for the retained window.
/// All database reads are performed off the main actor via `Task.detached`.
public struct AppKitMessagePagination: Sendable {
    public let pageSize: Int
    public let maxRetainedCount: Int

    public init(pageSize: Int = 40, maxRetainedCount: Int = 300) {
        self.pageSize = pageSize
        self.maxRetainedCount = maxRetainedCount
    }

    public struct LoadFirstPageResult: Sendable {
        public let messages: [LumiChatMessage]
        public let hasEarlierMessages: Bool
    }

    public struct LoadEarlierResult: Sendable {
        public let anchorID: UUID
        public let earlier: [LumiChatMessage]
        public let hasEarlierMessages: Bool
    }

    public struct RefreshTailResult: Sendable {
        public let merged: [LumiChatMessage]
        public let hasEarlierMessages: Bool?
    }

    /// Loads the newest page and probes whether an earlier page exists.
    public func loadFirstPage(
        conversationID: UUID,
        messageManager: (any MessageManaging)?
    ) async -> LoadFirstPageResult {
        guard let messageManager else {
            return LoadFirstPageResult(messages: [], hasEarlierMessages: false)
        }
        let page: [LumiChatMessage]? = await read {
            messageManager.messagePage(
                for: conversationID, limit: pageSize, beforeMessageID: nil
            )
        }
        let safePage = page ?? []
        let hasEarlier: Bool = await read {
            messageManager.hasEarlierMessages(
                for: conversationID, beforeMessageID: safePage.first?.id
            )
        } ?? false
        return LoadFirstPageResult(
            messages: safePage,
            hasEarlierMessages: hasEarlier
        )
    }

    /// Prepends one older page before the current first message.
    ///
    /// Returns `nil` when there is nothing to do (no earlier page, no current
    /// anchor, empty DB page, or missing manager). The caller is responsible
    /// for reentrancy via its own `isLoadingEarlier` flag.
    public func loadEarlier(
        conversationID: UUID,
        messageManager: (any MessageManaging)?,
        currentFirstID: UUID?,
        hasEarlier: Bool
    ) async -> LoadEarlierResult? {
        guard hasEarlier,
              let currentFirstID,
              let messageManager else { return nil }
        let earlier: [LumiChatMessage]? = await read {
            messageManager.messagePage(
                for: conversationID, limit: pageSize, beforeMessageID: currentFirstID
            )
        }
        guard let earlier, !earlier.isEmpty else { return nil }
        let stillHas: Bool = await read {
            messageManager.hasEarlierMessages(
                for: conversationID, beforeMessageID: earlier.first?.id
            )
        } ?? false
        return LoadEarlierResult(
            anchorID: currentFirstID,
            earlier: earlier,
            hasEarlierMessages: stillHas
        )
    }

    /// Refreshes the tail against the newest page, preserving earlier history.
    ///
    /// Returns `nil` when there is nothing to merge: missing manager, empty
    /// newest page, or no overlap with a non-empty current window (user is
    /// browsing history — the UI should show a "new messages" hint instead).
    public func refreshTail(
        conversationID: UUID,
        messageManager: (any MessageManaging)?,
        current: [LumiChatMessage]
    ) async -> RefreshTailResult? {
        guard let messageManager else { return nil }
        let latestPage: [LumiChatMessage]? = await read {
            messageManager.messagePage(
                for: conversationID, limit: pageSize, beforeMessageID: nil
            )
        }
        guard let latestPage, !latestPage.isEmpty else { return nil }

        let latestIDs = Set(latestPage.map(\.id))
        if let firstOverlapIndex = current.firstIndex(where: { latestIDs.contains($0.id) }) {
            let merged = Array(current[..<firstOverlapIndex]) + latestPage
            return RefreshTailResult(merged: merged, hasEarlierMessages: nil)
        }
        if current.isEmpty {
            let hasEarlier: Bool = await read {
                messageManager.hasEarlierMessages(
                    for: conversationID, beforeMessageID: latestPage.first?.id
                )
            } ?? false
            return RefreshTailResult(
                merged: latestPage,
                hasEarlierMessages: hasEarlier
            )
        }
        return nil
    }

    /// Evicts the tail once the retained window exceeds `maxRetainedCount`,
    /// but only when the user is not at the bottom (never cut the live tail).
    public func evictTailIfNeeded(
        messages: [LumiChatMessage],
        isAtBottom: Bool
    ) -> [LumiChatMessage] {
        guard messages.count > maxRetainedCount, !isAtBottom else { return messages }
        let overflow = messages.count - maxRetainedCount
        var trimmed = messages
        trimmed.removeLast(overflow)
        return trimmed
    }

    // MARK: - Helpers

    private func read<T: Sendable>(
        _ body: @escaping @Sendable () -> T
    ) async -> T? {
        await Task.detached(priority: .userInitiated) { body() }.value
    }
}
