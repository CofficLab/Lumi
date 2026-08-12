import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

private struct MessageListV1Presentation: Equatable {
    var turnItems: [AgentTurnSummaryItem] = []
    /// 已落库、但尚未被当前可见 AgentTurn 认领的用户消息。
    var pendingUserMessages: [LumiChatMessage] = []
}

/// V1-only data source that pages AgentTurns and projects each turn into a
/// live process plus terminal result. Persisted process messages are rebuilt
/// with the turn snapshot; high-frequency streaming text is published separately.
@MainActor
final class ListV1ViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-list.v1-viewmodel")
    nonisolated static let emoji = "📑"
    nonisolated static let verbose = false

    @Published private var presentation = MessageListV1Presentation()
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingEarlier = false
    @Published private(set) var hasEarlierTurns = false
    /// 当前会话的流式助手消息。独立于持久化投影，逐 token 只更新活跃 Turn。
    @Published private(set) var streamingMessage: LumiChatMessage?

    private let kernel: LumiKernel
    private let builder = AgentTurnSummaryBuilder()
    private let refreshGate = MessageListTailRefreshGate()
    private let pageSize: Int
    private var records: [AgentTurnRecord] = [] // newest first
    private var activeConversationID: UUID?
    /// 激活序列号，用于防止并发 activate 的竞态。
    /// 每次 activate 调用时递增，异步操作完成后检查序列号是否匹配。
    private var activationSequence: UInt64 = 0
    private var cancellables: Set<AnyCancellable> = []
    private var didBindMessageNotifications = false
    private var didBindServices = false
    private var didBindStreaming = false
    private var streamingRefreshTask: Task<Void, Never>?

    init(kernel: LumiKernel, pageSize: Int = 40) {
        self.kernel = kernel
        self.pageSize = pageSize
    }

    var items: [AgentTurnSummaryItem] { presentation.turnItems }
    var pendingUserMessages: [LumiChatMessage] { presentation.pendingUserMessages }
    /// 供滚动辅助器与“自己刚发送”检测使用的完整可见消息序列。
    var displayMessages: [LumiChatMessage] {
        let turnMessages = presentation.turnItems.flatMap { item in
            if let userMessage = item.userMessage {
                return [userMessage, item.message]
            }
            return [item.message]
        }
        return (turnMessages + presentation.pendingUserMessages).sorted(by: messageOrdering)
    }
    var hasVisibleContent: Bool { !items.isEmpty || !pendingUserMessages.isEmpty }

    /// 用户当前选中的对话 ID（来自内核状态，反映真实意图）。
    /// 用于替代 `activeConversationID` 做过期守卫，避免并发 `activate` 导致竞态。
    var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    func activate(conversationID: UUID?) async {
        if Self.verbose {
            Self.logger.info("\(self.t)激活会话：\(conversationID?.uuidString ?? "nil")")
        }
        bindServicesIfNeeded()
        // 记录当前激活序列号，用于后续异步操作完成后检查是否过期
        activationSequence &+= 1
        let mySequence = activationSequence

        activeConversationID = conversationID
        streamingMessage = nil
        isLoading = true
        defer { isLoading = false }

        guard let conversationID,
              let turnManager = kernel.agentTurnManager else {
            // 无对话 ID 或无 turnManager 时，清空状态
            if mySequence == activationSequence {
                records = []
                presentation = MessageListV1Presentation()
                hasEarlierTurns = false
            }
            return
        }

        let page = await turnManager.turnRecords(
            for: conversationID,
            limit: pageSize + 1,
            before: nil
        )
        // 检查序列号和 selectedConversationID，确保本次激活仍然有效
        guard mySequence == activationSequence,
              selectedConversationID == conversationID else { return }

        // 只在序列号匹配时更新状态，避免被后续 activate 的结果覆盖
        hasEarlierTurns = page.count > pageSize
        records = Array(page.prefix(pageSize))
        if Self.verbose {
            Self.logger.info("\(self.t)Turn 记录加载完成: \(self.records.count) 条")
        }
        await rebuildItems(for: conversationID, sequence: mySequence)
        applyStreamingState()
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
        guard selectedConversationID == conversationID else { return false }

        let previousPresentation = presentation
        var byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for record in latest.prefix(pageSize) {
            byID[record.id] = record
        }
        records = byID.values.sorted(by: newestRecordFirst)
        if records.count <= pageSize {
            hasEarlierTurns = latest.count > pageSize
        }
        await rebuildItems(for: conversationID, sequence: activationSequence)
        return presentation != previousPresentation
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
        guard selectedConversationID == conversationID else { return nil }

        let older = Array(page.prefix(pageSize))
        guard !older.isEmpty else {
            hasEarlierTurns = false
            return nil
        }

        let existingIDs = Set(records.map(\.id))
        records.append(contentsOf: older.filter { !existingIDs.contains($0.id) })
        records.sort(by: newestRecordFirst)
        hasEarlierTurns = page.count > pageSize
        await rebuildItems(for: conversationID, sequence: activationSequence)
        return anchorID
    }

    private func rebuildItems(for conversationID: UUID, sequence: UInt64) async {
        guard let messageManager = kernel.messageManager else {
            if sequence == activationSequence {
                presentation = MessageListV1Presentation()
            }
            return
        }
        let messages = await Task.detached(priority: .userInitiated) {
            messageManager.messages(for: conversationID)
        }.value
        // 检查序列号，确保本次重建仍然有效
        guard sequence == activationSequence,
              selectedConversationID == conversationID else { return }
        // builder 聚合已落库/瞬时过程；逐 token 的流式正文由独立属性承载。
        let turnItems = builder.build(records: records, messages: messages)
        let claimedUserMessageIDs = Set(turnItems.compactMap { $0.userMessage?.id })
        // records 是分页窗口，不能把窗口之外的旧用户消息误判为 pending。
        // 真正待认领的发送只会出现在当前最新 Turn 启动之后。
        let newestVisibleTurnStartedAt = records.map(\.startedAt).max()
        let pendingUserMessages = messages
            .filter { message in
                guard message.role == .user,
                      !claimedUserMessageIDs.contains(message.id) else { return false }
                guard let newestVisibleTurnStartedAt else { return true }
                return message.createdAt > newestVisibleTurnStartedAt
            }
            .sorted(by: messageOrdering)
        presentation = MessageListV1Presentation(
            turnItems: turnItems,
            pendingUserMessages: pendingUserMessages
        )
    }

    private func newestRecordFirst(_ lhs: AgentTurnRecord, _ rhs: AgentTurnRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString > rhs.id.uuidString }
        return lhs.startedAt > rhs.startedAt
    }

    private func messageOrdering(_ lhs: LumiChatMessage, _ rhs: LumiChatMessage) -> Bool {
        if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.createdAt < rhs.createdAt
    }

    /// 只有最新的未结束 Turn 消费当前会话的流式消息，防止它串到历史 Turn。
    func liveStreamingMessage(for item: AgentTurnSummaryItem) -> LumiChatMessage? {
        guard item.isShowingProcess,
              items.last(where: \.isShowingProcess)?.id == item.id,
              streamingMessage?.conversationID == item.record.conversationID else { return nil }
        return streamingMessage
    }

    private func bindServicesIfNeeded() {
        // 必须由 ViewModel 自己监听：空对话时 List 尚未创建，View 内的监听器不存在。
        // 第一条用户消息正是在这个阶段到达。
        if !didBindMessageNotifications {
            NotificationCenter.default.publisher(for: .lumiMessagesDidChange)
                .filter { [weak self] notification in
                    guard let self else { return false }
                    return MessageListNotificationFilter.shouldHandle(
                        eventConversationID: notification.lumiConversationID,
                        selectedConversationID: self.selectedConversationID
                    )
                }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.refresh()
                    }
                }
                .store(in: &cancellables)
            didBindMessageNotifications = true
        }

        if !didBindServices, let sender = kernel.messageSender {
            sender.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.refresh()
                    }
                }
                .store(in: &cancellables)
            didBindServices = true
        }

        guard !didBindStreaming, let streaming = kernel.messageStreaming else { return }
        streaming.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleStreamingRefresh()
            }
            .store(in: &cancellables)
        didBindStreaming = true
    }

    /// 合并高频 token 广播，最多每帧更新一次 V1 活跃 Turn。
    private func scheduleStreamingRefresh() {
        guard streamingRefreshTask == nil else { return }
        streamingRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, let self else { return }
            self.streamingRefreshTask = nil
            self.applyStreamingState()
        }
    }

    private func applyStreamingState() {
        guard let conversationID = activeConversationID,
              selectedConversationID == conversationID,
              let streaming = kernel.messageStreaming else {
            streamingMessage = nil
            return
        }
        let stage = streaming.streamingStage(for: conversationID)
        let row = streaming.streamingRow(for: conversationID)
        if (stage == .thinking || stage == .generating),
           let row,
           row.conversationID == conversationID {
            streamingMessage = row
        } else {
            streamingMessage = nil
        }
    }
}
