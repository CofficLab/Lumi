import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class ConversationListContext: ObservableObject, SuperLog {
    public nonisolated static let emoji = "📜"
    public nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "conversation-list.context")

    @Published public private(set) var lastChange: ConversationListChange?
    @Published public private(set) var statusVersion: Int = 0
    @Published public private(set) var unreadCount: Int = 0
    @Published public private(set) var messageVersion: Int = 0
    /// 发送状态版本号:每次 `MessageSending.sendingConversationIDs` 变化时 +1,
    /// 让 SwiftUI 在 `isConversationProcessing(_:)` 返回值变化时重新渲染。
    /// 直接调用 `isConversationProcessing` 不会触发重画(@Published 没变),
    /// 所以这里把"我刚问过且答案变了"翻译成一个版本号供视图层 `.onChange` 订阅。
    @Published public private(set) var sendingVersion: Int = 0

    private let kernel: LumiKernel
    private let conversationManaging: any ConversationManaging
    private let messageManaging: (any MessageManaging)?
    /// 真实发送状态持有者(`MessageSender`)。`ConversationManaging.isSending(for:)`
    /// 是 stub,会永远返回 false,所以这里必须直接拿 `MessageSending` 才能拿到真实状态。
    private let messageSending: (any MessageSending)?
    private var conversationSnapshots: [UUID: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var previousConversations: [LumiConversationSummary] = []
    private var previousSelectedID: UUID?
    private var syncTimer: AnyCancellable?
    /// 最近一次 `MessageSending.sendingConversationIDs` 快照,用于去重:
    /// 版本号只在"集合真的变了"时才 +1,避免重复触发全列表重渲染。
    private var lastProcessedSendingIDs: Set<UUID> = []

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        self.conversationManaging = kernel.conversations!
        self.messageManaging = kernel.messageManager
        self.messageSending = kernel.messageSender
        self.previousConversations = kernel.conversations!.conversations
        self.previousSelectedID = kernel.conversations!.selectedConversationID

        conversationSnapshots = Dictionary(
            uniqueKeysWithValues: kernel.conversations!.conversations.map { ($0.id, $0.updatedAt) }
        )
        bindConversationManaging()
        bindMessageManaging()
        bindMessageSending()
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
            // Pinned conversations first (order > 0), sorted by order ascending
            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }
            // Then sort by updatedAt descending
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
        messageSending?.isSending(for: conversationID) ?? false
    }

    /// 当前所有正在发送的对话 ID,供视图层做"任意会话在发送"等粗粒度判断。
    public var sendingConversationIDs: Set<UUID> {
        // MessageSender 内部以 Set<UUID> 存储,但协议只暴露 isSending(for:);
        // 这里用全量 conversations + 逐个问询来重建集合。
        // 列表规模有限(N<=可见分页 40),O(N) 开销可接受。
        let all = conversationManaging.conversations.map(\.id)
        return Set(all.filter { messageSending?.isSending(for: $0) == true })
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
        try! conversationManaging.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
    }

    public func switchProject(projectPath: String, reason: String) {
        // No-op in this context. Project switching is handled externally.
    }

    /// Set conversation order for pinning/unpinning
    public func setConversationOrder(_ order: Int, for conversationID: UUID) {
        conversationManaging.setConversationOrder(order, for: conversationID)
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

    /// 订阅 `MessageSending.objectWillChange`,在发送集合变化时 bump `sendingVersion`,
    /// 让视图层可以基于"版本号变了 → 重渲染"来决定是否需要重新读取 `isConversationProcessing`。
    ///
    /// 这里不去重原始信号(MessageSender 每次改动都会触发),
    /// 而是在去重函数里比较"当前集合"与"上次集合"是否真的不同,
    /// 这样可以避免无意义的版本号 +1。
    private func bindMessageSending() {
        guard let messageSending else { return }
        // 初始化时记一下当前集合,避免启动瞬间被当成"变了"
        lastProcessedSendingIDs = sendingConversationIDs

        messageSending.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleSendingVersionRefresh()
            }
            .store(in: &cancellables)
    }

    /// 异步 bump `sendingVersion`,延迟到下一帧执行,确保读到的是
    /// `MessageSender` 已经写入的最新 `sendingConversationIDs`(objectWillChange
    /// 在属性写入前发出,所以必须等 setter 实际生效之后再读)。
    private func scheduleSendingVersionRefresh() {
        Task { @MainActor [weak self] in
            // 给一个 RunLoop tick,等待 setter 完成
            await Task.yield()
            self?.refreshSendingVersionIfNeeded()
        }
    }

    /// 比较"当前正在发送的对话集合"与上次快照,
    /// 仅在集合确实变化时 bump `sendingVersion`,触发视图重渲染。
    private func refreshSendingVersionIfNeeded() {
        let current = sendingConversationIDs
        guard current != lastProcessedSendingIDs else { return }
        lastProcessedSendingIDs = current
        sendingVersion += 1
        if Self.verbose {
            Self.logger.info("\(Self.t)sendingVersion bumped ➡️ \(current)")
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
        let idsChanged = previousIDs != currentIDs
        let selectionChanged = previousSelectedID != currentSelected
        let updatedConversationID = currentIDs.intersection(previousIDs).first(where: { id in
            let prev = previousConversations.first { $0.id == id }
            let curr = current.first { $0.id == id }
            return prev?.updatedAt != curr?.updatedAt
        })

        if let deletedID = previousIDs.subtracting(currentIDs).first {
            lastChange = ConversationListChange(type: .deleted, conversationId: deletedID)
        } else if let updatedID = updatedConversationID {
            lastChange = ConversationListChange(type: .updated, conversationId: updatedID)
        }

        previousConversations = current
        previousSelectedID = currentSelected

        // Do not publish on every polling tick. In particular, when the
        // persistent store failed to load and the source remains empty, an
        // unconditional version bump causes the list view to reload forever.
        guard idsChanged || selectionChanged || updatedConversationID != nil else {
            recalculateUnreadCount()
            return
        }

        statusVersion += 1
        recalculateUnreadCount()
    }
}
