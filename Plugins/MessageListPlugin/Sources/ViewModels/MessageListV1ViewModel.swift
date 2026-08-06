import Foundation
import LumiKernel

/// V1-only data source that pages AgentTurns and projects each turn to one
/// user-facing response. The regular MessageListViewModel remains responsible
/// for live streaming and for legacy conversations without turn metadata.
@MainActor
final class MessageListV1ViewModel: ObservableObject {
    @Published private(set) var items: [AgentTurnSummaryItem] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingEarlier = false
    @Published private(set) var hasEarlierTurns = false

    private let kernel: LumiKernel
    private let builder = AgentTurnSummaryBuilder()
    private let refreshGate = MessageListTailRefreshGate()
    private let pageSize: Int
    private var records: [AgentTurnRecord] = [] // newest first
    private var activeConversationID: UUID?

    init(kernel: LumiKernel, pageSize: Int = 40) {
        self.kernel = kernel
        self.pageSize = pageSize
    }

    var usesTurnProjection: Bool { !items.isEmpty }
    var displayMessages: [LumiChatMessage] { items.map(\.message) }

    func activate(conversationID: UUID?) async {
        activeConversationID = conversationID
        records = []
        items = []
        hasEarlierTurns = false
        isLoading = true
        defer { isLoading = false }

        guard let conversationID,
              let turnManager = kernel.agentTurnManager else { return }

        let page = await turnManager.turnRecords(
            for: conversationID,
            limit: pageSize + 1,
            before: nil
        )
        guard activeConversationID == conversationID else { return }

        hasEarlierTurns = page.count > pageSize
        records = Array(page.prefix(pageSize))
        await rebuildItems(for: conversationID)
    }

    /// Refreshes the newest Turn page while retaining any earlier pages the
    /// user already loaded. Returns true only when the visible projection changed.
    @discardableResult
    func refresh() async -> Bool {
        await refreshGate.run { [weak self] in
            guard let self else { return false }
            return await self.performRefresh()
        }
    }

    private func performRefresh() async -> Bool {
        guard let conversationID = activeConversationID,
              let turnManager = kernel.agentTurnManager else { return false }

        let latest = await turnManager.turnRecords(
            for: conversationID,
            limit: pageSize + 1,
            before: nil
        )
        guard activeConversationID == conversationID else { return false }

        let previousItems = items
        var byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for record in latest.prefix(pageSize) {
            byID[record.id] = record
        }
        records = byID.values.sorted(by: newestRecordFirst)
        if records.count <= pageSize {
            hasEarlierTurns = latest.count > pageSize
        }
        await rebuildItems(for: conversationID)
        return items != previousItems
    }

    /// Prepends one older Turn page and returns the previously oldest visible
    /// Turn ID so the view can preserve its scroll position.
    func loadEarlier() async -> UUID? {
        guard hasEarlierTurns,
              !isLoadingEarlier,
              let conversationID = activeConversationID,
              let cursor = records.last?.id,
              let anchorID = items.first?.id,
              let turnManager = kernel.agentTurnManager else { return nil }

        isLoadingEarlier = true
        defer { isLoadingEarlier = false }

        let page = await turnManager.turnRecords(
            for: conversationID,
            limit: pageSize + 1,
            before: cursor
        )
        guard activeConversationID == conversationID else { return nil }

        let older = Array(page.prefix(pageSize))
        guard !older.isEmpty else {
            hasEarlierTurns = false
            return nil
        }

        let existingIDs = Set(records.map(\.id))
        records.append(contentsOf: older.filter { !existingIDs.contains($0.id) })
        records.sort(by: newestRecordFirst)
        hasEarlierTurns = page.count > pageSize
        await rebuildItems(for: conversationID)
        return anchorID
    }

    private func rebuildItems(for conversationID: UUID) async {
        guard let messageManager = kernel.messageManager else {
            items = []
            return
        }
        let messages = await Task.detached(priority: .userInitiated) {
            messageManager.messages(for: conversationID)
        }.value
        guard activeConversationID == conversationID else { return }
        items = builder.build(records: records, messages: messages)
    }

    private func newestRecordFirst(_ lhs: AgentTurnRecord, _ rhs: AgentTurnRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString > rhs.id.uuidString }
        return lhs.startedAt > rhs.startedAt
    }
}
