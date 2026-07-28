import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class ConversationListContext: ObservableObject, SuperLog {
    public nonisolated static let emoji = "📜"
    public nonisolated static let verbose = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "conversation-list.context")

    @Published public private(set) var lastChange: ConversationListChange?
    @Published public private(set) var statusVersion: Int = 0
    @Published public private(set) var unreadCount: Int = 0
    @Published public private(set) var messageVersion: Int = 0

    private let kernel: LumiKernel
    private let conversationManaging: any ConversationManaging
    private let messageManaging: (any MessageManaging)?
    private var conversationSnapshots: [UUID: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var previousConversations: [LumiConversationSummary] = []
    private var previousSelectedID: UUID?
    private var syncTimer: AnyCancellable?

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        self.conversationManaging = kernel.conversations!
        self.messageManaging = kernel.messageManager
        self.previousConversations = kernel.conversations!.conversations
        self.previousSelectedID = kernel.conversations!.selectedConversationID

        conversationSnapshots = Dictionary(
            uniqueKeysWithValues: kernel.conversations!.conversations.map { ($0.id, $0.updatedAt) }
        )
        bindConversationManaging()
        bindMessageManaging()
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

    public var conversationCount: Int {
        conversationManaging.conversations.count
    }

    public func fetchConversationsPage(limit: Int, offset: Int) async -> [ConversationListItem] {
        if Self.verbose {
            Self.logger.info("\(Self.t)fetchConversationsPage start limit=\(limit) offset=\(offset) totalConversations=\(self.conversationManaging.conversations.count)")
        }
        let sorted = conversationManaging.conversations.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        var items: [ConversationListItem] = []
        items.reserveCapacity(limit)
        for summary in sorted.dropFirst(offset).prefix(limit) {
            let count = await messageCount(for: summary.id)
            items.append(ConversationListItem.from(summary, messageCount: count, uiTitle: uiTitle(for: summary)))
        }
        if Self.verbose {
            let countedItems = items.filter { $0.messageCount != nil }.count
            let totalMessages = items.reduce(0) { $0 + ($1.messageCount ?? 0) }
            Self.logger.info("\(Self.t)fetchConversationsPage done limit=\(limit) offset=\(offset) items=\(items.count) countedItems=\(countedItems) pageMessageCountSum=\(totalMessages)")
        }
        return items
    }

    public func fetchConversation(id: UUID) async -> ConversationListItem? {
        guard let summary = conversationManaging.conversations.first(where: { $0.id == id }) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)fetchConversation missing id=\(id.uuidString.prefix(8))")
            }
            return nil
        }
        let count = await messageCount(for: id)
        if Self.verbose {
            Self.logger.info("\(Self.t)fetchConversation id=\(id.uuidString.prefix(8)) messageCount=\(count ?? -1)")
        }
        return ConversationListItem.from(summary, messageCount: count, uiTitle: uiTitle(for: summary))
    }

    /// 委托给 LumiKernel 级 ``LumiKernelContainer/uiTitle(for:)`` 解析该对话的 UI 标题。
    private func uiTitle(for summary: LumiConversationSummary) -> String {
        kernel.uiTitle(for: summary.id)
    }

    public func isConversationProcessing(_ conversationID: UUID) -> Bool {
        conversationManaging.isSending(for: conversationID)
    }

    public func messageCount(for conversationID: UUID) async -> Int? {
        guard let messageManaging else { return nil }
        let count = await messageManaging.messageCount(for: conversationID)
        if Self.verbose {
            Self.logger.info("\(Self.t)messageCount conversation=\(conversationID.uuidString.prefix(8)) count=\(count)")
        }
        return count
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
        try! conversationManaging.createConversation(title: nil, projectPath: nil)
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

    private func bindMessageManaging() {
        guard messageManaging != nil else { return }

        NotificationCenter.default.publisher(for: .lumiMessagesDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.messageVersion += 1
            }
            .store(in: &cancellables)
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
