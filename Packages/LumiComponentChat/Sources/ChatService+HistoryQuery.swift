import Foundation
import LumiComponentMessage

extension ChatService: HistoryQueryService {
    public func fetchMessageCount() async -> Int {
        store.historyMessageCount()
    }

    public func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow] {
        store.historyMessagePage(limit: limit, offset: offset)
    }

    public func fetchConversationCount() async -> Int {
        store.historyConversationCount()
    }

    public func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow] {
        store.historyConversationPage(limit: limit, offset: offset)
    }

    /// Runs the actual read **off the main actor**: the `Sendable` container is
    /// captured into a detached task that builds a throwaway `ModelContext` and
    /// runs a single windowed, timestamp-only query. The caller awaits from the
    /// main actor but the work never blocks the UI. See `HistoryQueryService`.
    public func fetchDailyMessageCounts(since: Date) async -> [Date: Int] {
        let container = backgroundQueryContainer
        return await Task.detached(priority: .userInitiated) {
            ChatStore.dailyMessageCounts(container: container, since: since)
        }.value
    }

    /// Runs the actual read **off the main actor**: the `Sendable` container is
    /// captured into a detached task that builds a throwaway `ModelContext` and
    /// joins message timestamps with metric token counts to produce per-day
    /// token sums. The caller awaits from the main actor but the work never
    /// blocks the UI. See `HistoryQueryService`.
    public func fetchDailyTokenCounts(since: Date) async -> [Date: Int] {
        let container = backgroundQueryContainer
        return await Task.detached(priority: .userInitiated) {
            ChatStore.dailyTokenCounts(container: container, since: since)
        }.value
    }
}
