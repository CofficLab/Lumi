import Combine
import Foundation
import ProviderAgentLoop
import ProviderMessage

/// V1-only data source that pages AgentTurns and projects each turn into a
/// live process plus terminal result. Persisted process messages are rebuilt
/// with the turn snapshot; high-frequency streaming text is published separately.
///
/// 新版适配：`AgentTurnProviding` 没有持久化的 turn 记录存储，`records`
/// 由 `AgentTurnRecordBuilder` 从消息 `turnID` 分组重建（按 startedAt 排序），
/// turn 分页即对该重建序列做窗口切片。
@MainActor
final class ListV1ViewModel: ObservableObject {
    @Published private var presentation = ListV1Presentation()
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingEarlier = false
    @Published private(set) var hasEarlierTurns = false
    /// 仅供分页/滚动与既有回归测试使用，不传给 AgentTurnView。
    private var summaryItems: [AgentTurnSummaryItem] = []
    private var pendingUserSnapshot: [Message] = []
    private var pendingStatusSnapshot: Message?

    private let services: MessageListServices
    private let builder = AgentTurnSummaryBuilder()
    private let refreshGate = MessageListTailRefreshGate()
    private let pageSize: Int
    private var records: [AgentTurnRecord] = [] // newest first
    private var activeConversationID: UUID?
    /// 激活序列号，用于防止并发 activate 的竞态。
    private var activationSequence: UInt64 = 0
    private var cancellables: Set<AnyCancellable> = []
    private var didBindMessageChanges = false

    init(services: MessageListServices, pageSize: Int = 40) {
        self.services = services
        self.pageSize = pageSize
    }

    /// ListV1View 的唯一数据源：每一项都对应一个 AgentTurnView。
    var agentTurns: [AgentTurnPresentationItem] { presentation.agentTurns }

    // 旧粒度只读访问器仅保留给行为回归测试；视图层不得使用。
    var items: [AgentTurnSummaryItem] { summaryItems }
    var pendingUserMessages: [Message] { pendingUserSnapshot }
    var pendingStatusMessage: Message? { pendingStatusSnapshot }
    /// 供滚动辅助器与"自己刚发送"检测使用的完整可见消息序列。
    var displayMessages: [Message] {
        let turnMessages = summaryItems.flatMap { item in
            (item.userMessage.map { [$0] } ?? []) + [item.message]
        }
        return turnMessages
            + pendingUserSnapshot
            + (pendingStatusSnapshot.map { [$0] } ?? [])
            .sorted(by: messageOrdering)
    }

    var hasVisibleContent: Bool { !agentTurns.isEmpty }

    /// 用户当前选中的对话 ID（来自内核状态，反映真实意图）。
    var selectedConversationID: UUID? {
        services.selectedConversationID
    }

    func activate(conversationID: UUID?) async {
        bindServicesIfNeeded()
        // 记录当前激活序列号，用于后续异步操作完成后检查是否过期
        activationSequence &+= 1
        let mySequence = activationSequence

        activeConversationID = conversationID
        isLoading = true
        defer { isLoading = false }

        guard let conversationID,
              let messageManager = services.messages else {
            // 无对话 ID 或无 messageManager 时，清空状态
            if mySequence == activationSequence {
                records = []
                presentation = ListV1Presentation()
                summaryItems = []
                pendingUserSnapshot = []
                pendingStatusSnapshot = nil
                hasEarlierTurns = false
            }
            return
        }

        let allMessages = await messageManager.messagesSnapshot(in: conversationID)
        let conversationState = services.agentTurn?.state(for: conversationID) ?? .idle
        let allRecords = AgentTurnRecordBuilder.records(
            from: allMessages,
            conversationID: conversationID,
            conversationState: conversationState
        ).sorted(by: newestRecordFirst)

        // 检查序列号，确保本次激活仍然有效
        guard mySequence == activationSequence,
              selectedConversationID == conversationID else { return }

        hasEarlierTurns = allRecords.count > pageSize
        records = Array(allRecords.prefix(pageSize))
        await rebuildItems(for: conversationID, sequence: mySequence, allMessages: allMessages)
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
              let messageManager = services.messages else { return false }

        let allMessages = await messageManager.messagesSnapshot(in: conversationID)
        guard selectedConversationID == conversationID else { return false }

        let conversationState = services.agentTurn?.state(for: conversationID) ?? .idle
        let latest = AgentTurnRecordBuilder.records(
            from: allMessages,
            conversationID: conversationID,
            conversationState: conversationState
        ).sorted(by: newestRecordFirst)

        let previousPresentation = presentation
        var byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for record in latest.prefix(pageSize) {
            byID[record.id] = record
        }
        records = byID.values.sorted(by: newestRecordFirst)
        if records.count <= pageSize {
            hasEarlierTurns = latest.count > pageSize
        }
        await rebuildItems(for: conversationID, sequence: activationSequence, allMessages: allMessages)
        return presentation != previousPresentation
    }

    /// Prepends one older Turn page and returns the previously oldest visible
    /// Turn ID so the view can preserve its scroll position.
    func loadEarlier() async -> UUID? {
        guard hasEarlierTurns,
              !isLoadingEarlier,
              let conversationID = activeConversationID,
              let cursor = records.last?.id,
              let anchorID = agentTurns.first?.id,
              let messageManager = services.messages else { return nil }

        isLoadingEarlier = true
        defer { isLoadingEarlier = false }

        let allMessages = await messageManager.messagesSnapshot(in: conversationID)
        guard selectedConversationID == conversationID else { return nil }

        let conversationState = services.agentTurn?.state(for: conversationID) ?? .idle
        let allRecords = AgentTurnRecordBuilder.records(
            from: allMessages,
            conversationID: conversationID,
            conversationState: conversationState
        ).sorted(by: newestRecordFirst)

        // 已加载的 turn id 集合之外，取更早的一页（跳过已加载的）。
        let existingIDs = Set(records.map(\.id))
        let older = allRecords.filter { !existingIDs.contains($0.id) }
        guard !older.isEmpty else {
            hasEarlierTurns = false
            return nil
        }

        records.append(contentsOf: older.prefix(pageSize))
        records.sort(by: newestRecordFirst)
        hasEarlierTurns = older.count > pageSize
        await rebuildItems(for: conversationID, sequence: activationSequence, allMessages: allMessages)
        return anchorID
    }

    private func rebuildItems(for conversationID: UUID, sequence: UInt64, allMessages: [Message]) async {
        guard let messageManager = services.messages else {
            if sequence == activationSequence {
                presentation = ListV1Presentation()
                summaryItems = []
                pendingUserSnapshot = []
                pendingStatusSnapshot = nil
            }
            return
        }
        // 检查序列号，确保本次重建仍然有效
        guard sequence == activationSequence,
              selectedConversationID == conversationID else { return }
        // builder 聚合已落库/瞬时过程；逐 token 的流式正文由独立属性承载。
        let messages = allMessages.isEmpty
            ? await messageManager.messagesSnapshot(in: conversationID)
            : allMessages
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
        let hasActiveTurn = turnItems.contains(where: \.isShowingProcess)
        let pendingStatusMessage = hasActiveTurn
            ? nil
            : messages.last(where: { $0.role == .status })
        let latestActiveTurnID = turnItems.last(where: \.isShowingProcess)?.id
        var agentTurns = turnItems.map {
            AgentTurnPresentationItem(
                recorded: $0,
                acceptsLiveActivity: $0.id == latestActiveTurnID
            )
        }
        if !pendingUserMessages.isEmpty {
            for (index, userMessage) in pendingUserMessages.enumerated() {
                agentTurns.append(AgentTurnPresentationItem(
                    pendingUserMessages: [userMessage],
                    statusMessage: index == pendingUserMessages.indices.last
                        ? pendingStatusMessage
                        : nil
                ))
            }
        } else if let pendingStatusMessage {
            agentTurns.append(AgentTurnPresentationItem(
                pendingUserMessages: [],
                statusMessage: pendingStatusMessage
            ))
        }
        summaryItems = turnItems
        pendingUserSnapshot = pendingUserMessages
        pendingStatusSnapshot = pendingStatusMessage
        presentation = ListV1Presentation(agentTurns: agentTurns)
    }

    private func newestRecordFirst(_ lhs: AgentTurnRecord, _ rhs: AgentTurnRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString > rhs.id.uuidString }
        return lhs.startedAt > rhs.startedAt
    }

    private func bindServicesIfNeeded() {
        // 必须由 ViewModel 自己监听：空对话时 List 尚未创建，View 内的监听器不存在。
        // 第一条用户消息正是在这个阶段到达。
        guard !didBindMessageChanges else { return }
        guard let messages = services.messages else { return }
        messages.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
        didBindMessageChanges = true
    }
}
