import Foundation
import ProviderAgentLoop
import ProviderMessage

/// 当前对话的消息列表数据源：负责消息窗口、分页和列表行投影，并为每个
/// AgentTurn 保持对应的子 VM。持久化过程消息从有限消息窗口重建；
/// 高频流式正文由 AgentTurnVM 单独发布。
///
/// 新版适配：`AgentTurnProviding` 没有持久化的 turn 记录存储，`records`
/// 由 `AgentTurnRecordBuilder` 从消息 `turnID` 分组重建（按 startedAt 排序），
/// turn 分页即对该重建序列做窗口切片。
@MainActor
final class ConversationMessageListVM: ObservableObject {
    @Published private var presentation = ListV1Presentation()
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingEarlier = false
    @Published private(set) var hasEarlierTurns = false
    @Published private(set) var isDeveloperModeEnabled = false
    /// 供滚动辅助器使用，不传给 AgentTurnView。
    private var summaryItems: [AgentTurnSummaryItem] = []
    private var pendingUserSnapshot: [Message] = []
    private var pendingStatusSnapshot: Message?

    private let services: MessageListServices
    private let builder = AgentTurnSummaryBuilder()
    private let pagination: MessageListPaginationService
    private let refreshGate = MessageListTailRefreshGate()
    private var agentTurnVMs: [UUID: AgentTurnVM] = [:]
    /// 当前已加载的消息窗口，按时间升序排列。
    private var messageWindow: [Message] = []
    private var activeConversationID: UUID?
    /// 激活序列号，用于防止并发 activate 的竞态。
    private var activationSequence: UInt64 = 0

    init(services: MessageListServices, pageSize: Int = 40) {
        self.services = services
        self.pagination = MessageListPaginationService(pageSize: pageSize)
    }

    /// ListV1View 的唯一数据源：每一项都对应一个 AgentTurnView。
    var agentTurns: [AgentTurnPresentationItem] { presentation.agentTurns }
    /// AgentTurn 与独立时间线事件合并后的展示行。
    var rows: [ListV1PresentationRow] { presentation.rows }

    /// 供滚动辅助器与"自己刚发送"检测使用的完整可见消息序列。
    var displayMessages: [Message] {
        let turnMessages = summaryItems.flatMap { item in
            (item.userMessage.map { [$0] } ?? []) + [item.message]
        }
        return turnMessages
            + pendingUserSnapshot
            + (pendingStatusSnapshot.map { [$0] } ?? [])
            + presentation.timelineEvents
            .sorted(by: messageOrdering)
    }

    func agentTurnVM(for item: AgentTurnPresentationItem) -> AgentTurnVM {
        if let vm = agentTurnVMs[item.id] {
            Task { @MainActor in await vm.update(item: item) }
            return vm
        }
        let vm = AgentTurnVM(services: services, item: item)
        agentTurnVMs[item.id] = vm
        return vm
    }

    /// 用户当前选中的对话 ID（来自内核状态，反映真实意图）。
    var selectedConversationID: UUID? {
        services.selectedConversationID
    }

    func updateDeveloperMode(enabled: Bool) {
        guard isDeveloperModeEnabled != enabled else { return }
        isDeveloperModeEnabled = enabled
    }

    func activate(conversationID: UUID?) async {
        // Ignore requests for a selection that is no longer current. The view
        // uses activateCurrentConversation() so this only filters delayed
        // callbacks from an older selection.
        guard selectedConversationID == conversationID else { return }
        activationSequence &+= 1
        let mySequence = activationSequence

        activeConversationID = conversationID
        isLoading = true
        clearDisplayState()
        defer {
            if mySequence == activationSequence {
                isLoading = false
            }
        }

        guard let conversationID,
              let messageManager = services.messages else {
            // 无对话 ID 或无 messageManager 时，状态已在激活开始时清空。
            return
        }

        let page = await pagination.loadFirstPage(
            conversationID: conversationID,
            messageManager: messageManager
        )

        // 检查序列号，确保本次激活仍然有效
        guard mySequence == activationSequence,
              selectedConversationID == conversationID else { return }

        messageWindow = page.messages
        hasEarlierTurns = page.hasEarlierMessages
        rebuildWindow(for: conversationID, sequence: mySequence)
    }

    /// Starts activation with the selection observed at task execution time,
    /// not the value captured while SwiftUI was building the view hierarchy.
    func activateCurrentConversation() async {
        await activate(conversationID: selectedConversationID)
    }

    /// 切换会话时先清空旧会话的展示快照，避免异步首屏加载期间继续显示旧行。
    private func clearDisplayState() {
        messageWindow = []
        presentation = ListV1Presentation()
        summaryItems = []
        pendingUserSnapshot = []
        pendingStatusSnapshot = nil
        hasEarlierTurns = false
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

        guard let result = await pagination.refreshTail(
            conversationID: conversationID,
            messageManager: messageManager,
            current: messageWindow
        ) else { return false }
        guard selectedConversationID == conversationID else { return false }

        let previousPresentation = presentation
        messageWindow = result.merged
        if let hasEarlierMessages = result.hasEarlierMessages {
            hasEarlierTurns = hasEarlierMessages
        }
        rebuildWindow(for: conversationID, sequence: activationSequence)
        return presentation != previousPresentation
    }

    /// Prepends one older Turn page and returns the previously oldest visible
    /// Turn ID so the view can preserve its scroll position.
    func loadEarlier() async -> UUID? {
        guard hasEarlierTurns,
              !isLoadingEarlier,
              let conversationID = activeConversationID,
              let anchorID = agentTurns.first?.id,
              let messageManager = services.messages else { return nil }

        isLoadingEarlier = true
        defer { isLoadingEarlier = false }

        guard let result = await pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: messageManager,
            currentFirstID: messageWindow.first?.id,
            hasEarlier: hasEarlierTurns
        ) else { return nil }
        guard selectedConversationID == conversationID else { return nil }

        messageWindow = result.earlier + messageWindow
        hasEarlierTurns = result.hasEarlierMessages
        rebuildWindow(for: conversationID, sequence: activationSequence)
        return anchorID
    }

    private func rebuildWindow(for conversationID: UUID, sequence: UInt64) {
        guard services.messages != nil else {
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
        let conversationState = services.agentTurn?.state(for: conversationID) ?? .idle
        let records = AgentTurnRecordBuilder.records(
            from: messageWindow,
            conversationID: conversationID,
            conversationState: conversationState
        ).sorted(by: newestRecordFirst)
        // builder 聚合已落库/瞬时过程；逐 token 的流式正文由独立属性承载。
        let turnItems = builder.build(records: records, messages: messageWindow)
        let claimedUserMessageIDs = Set(turnItems.compactMap { $0.userMessage?.id })
        // records 是分页窗口，不能把窗口之外的旧用户消息误判为 pending。
        // 真正待认领的发送只会出现在当前最新 Turn 启动之后。
        let newestVisibleTurnStartedAt = records.map(\.startedAt).max()
        let pendingUserMessages = messageWindow
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
            : messageWindow.last(where: { $0.role == .status })
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
        // 仅展示确实用于一次上下文压缩的事件；旧版本的预热事件继续隐藏。
        let timelineEvents = messageWindow.filter(MessageTimelineEvent.isActualContextCompaction)
        presentation = ListV1Presentation(
            agentTurns: agentTurns,
            timelineEvents: timelineEvents
        )
    }

    private func newestRecordFirst(_ lhs: AgentTurnRecord, _ rhs: AgentTurnRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString > rhs.id.uuidString }
        return lhs.startedAt > rhs.startedAt
    }

    func handleSelectedConversationChange(_ conversationID: UUID?) {
        // Invalidate in-flight loads before the new activation task gets a
        // chance to run. Rapid conversation switching must not let an older
        // snapshot publish into the new List.
        activationSequence &+= 1
        Task { @MainActor [weak self] in
            await self?.activate(conversationID: conversationID)
        }
    }

    /// 将插入事件直接应用到当前消息窗口，避免新消息到达时重读数据库。
    func handleMessageChange(_ change: MessageChange) {
        switch change {
        case let .inserted(message, conversationID):
            guard conversationID == activeConversationID else { return }
            if let index = messageWindow.firstIndex(where: { $0.id == message.id }) {
                messageWindow[index] = message
            } else {
                messageWindow.append(message)
                messageWindow.sort(by: messageOrdering)
            }
            rebuildWindow(for: conversationID, sequence: activationSequence)
            refreshAgentTurnVMs()
        case let .persisted(_, conversationID),
             let .updated(conversationID: conversationID),
             let .deleted(_, conversationID: conversationID),
             let .cleared(conversationID: conversationID):
            guard conversationID == activeConversationID else { return }
            Task { @MainActor [weak self] in await self?.refresh() }
            refreshAgentTurnVMs()
        }
    }

    private func refreshAgentTurnVMs() {
        for vm in agentTurnVMs.values {
            Task { @MainActor in await vm.refresh() }
        }
    }
}
