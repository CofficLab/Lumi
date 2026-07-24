import Combine
import Foundation
import LumiKernel
import SwiftUI

@MainActor
public final class ConversationListContext: ObservableObject {
    @Published public private(set) var lastChange: ConversationListChange?
    @Published public private(set) var statusVersion: Int = 0
    @Published public private(set) var unreadCount: Int = 0

    private let conversationManaging: any ConversationManaging
    private var conversationSnapshots: [UUID: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var previousConversations: [LumiConversationSummary] = []
    private var previousSelectedID: UUID?
    private var syncTimer: AnyCancellable?

    public init(conversationManaging: any ConversationManaging) {
        self.conversationManaging = conversationManaging
        self.previousConversations = conversationManaging.conversations
        self.previousSelectedID = conversationManaging.selectedConversationID

        conversationSnapshots = Dictionary(
            uniqueKeysWithValues: conversationManaging.conversations.map { ($0.id, $0.updatedAt) }
        )
        bindConversationManaging()
    }

    public var selectedConversationId: UUID? {
        conversationManaging.selectedConversationID
    }

    private var selectedConversationUpdatedAt: Date? {
        guard let selectedConversationId else { return nil }
        return conversationManaging.conversations.first(where: { $0.id == selectedConversationId })?.updatedAt
    }

    private func recalculateUnreadCount() {
        let selectedUpdatedAt = selectedConversationUpdatedAt
        guard let selectedUpdatedAt else {
            unreadCount = 0
            return
        }

        unreadCount = conversationManaging.conversations.filter { $0.updatedAt > selectedUpdatedAt }.count
    }

    public var dataDirectory: URL {
        conversationManaging.dataDirectory
    }

    public func fetchConversationsPage(limit: Int, offset: Int) -> [ConversationListItem] {
        let sorted = conversationManaging.conversations.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        return sorted
            .dropFirst(offset)
            .prefix(limit)
            .map { ConversationListItem.from($0) }
    }

    public func fetchConversation(id: UUID) -> ConversationListItem? {
        conversationManaging.conversations.first(where: { $0.id == id }).map(ConversationListItem.from)
    }

    public func isConversationProcessing(_ conversationID: UUID) -> Bool {
        conversationManaging.isSending(for: conversationID)
    }

    @discardableResult
    public func deleteConversation(id: UUID) -> Bool {
        guard conversationManaging.conversations.contains(where: { $0.id == id }) else {
            return false
        }
        conversationManaging.deleteConversation(id: id)
        return true
    }

    public func selectConversation(_ id: UUID?, reason: String) {
        guard let id else { return }
        conversationManaging.selectConversation(id: id)
    }

    @discardableResult
    public func createConversation() -> UUID {
        try! conversationManaging.createConversation(title: nil)
    }

    public func switchProject(projectPath: String, reason: String) {
        // No-op in this context. Project switching is handled externally.
    }

    private func bindConversationManaging() {
        // Poll ConversationManaging for changes since we cannot use $conversations /
        // $selectedConversationID through the existential type.
        syncTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncFromSource()
            }
    }

    /// Sync state from ConversationManaging and publish granular changes.
    ///
    /// - Note: 不发布 `.created` 事件。"从无到 N 条" 这种批量初始化场景下,只通过 statusVersion++
    ///   通知 View 刷新;View 端的 handleStatusVersionChanged 已经会按需 reload 整个分页。
    ///   避免增量 `.created` 把"最新一条"插入到 view 的 conversations[0],污染正常排序的结果。
    private func syncFromSource() {
        let current = conversationManaging.conversations
        let currentSelected = conversationManaging.selectedConversationID

        let previousIDs = Set(previousConversations.map(\.id))
        let currentIDs = Set(current.map(\.id))

        if let deletedID = previousIDs.subtracting(currentIDs).first {
            lastChange = ConversationListChange(type: .deleted, conversationId: deletedID)
        } else if let updatedID = currentIDs.intersection(previousIDs).first(where: { id in
            let prev = previousConversations.first { $0.id == id }
            let curr = current.first { $0.id == id }
            return prev?.updatedAt != curr?.updatedAt
        }) {
            lastChange = ConversationListChange(type: .updated, conversationId: updatedID)
        }

        previousConversations = current
        previousSelectedID = currentSelected

        statusVersion += 1
        recalculateUnreadCount()
    }
}
