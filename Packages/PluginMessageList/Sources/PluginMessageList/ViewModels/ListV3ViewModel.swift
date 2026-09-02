import Combine
import Foundation
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming

/// Cheap fingerprint of the inputs that decide `MessageListRowBuilder.buildHistory`
/// output, used to skip the (O(rows × content) memberwise) `historyRows` array
/// comparison when nothing relevant changed between calls.
private struct HistoryBuildSignatureV3: Equatable {
    let conversationID: UUID?
    let verbosity: ResponseVerbosity
    /// 流式行可见性翻转时 status 行显隐不同，需纳入签名以触发重算。
    let hidesStatus: Bool
    /// Per persisted message — captures additions/removals/reordering AND
    /// content edits while staying far cheaper than comparing full content strings.
    let fingerprints: [MessageFingerprintV3]
}

private struct MessageFingerprintV3: Equatable {
    let id: UUID
    let contentLength: Int
    let role: MessageRole
    let isToolExecutionOnly: Bool
    let toolCallResultState: [String]
}

/// Message List V3 View Model (detailed / 详细模式)
///
/// 与 V2 的差异：V3 (detailed) 会**显示思考内容**（`reasoningContent`），
/// V2 (standard) 不显示。思考内容显示逻辑在此基础上增量加入；当前与 V2 行为一致，
/// 保留独立类型以便后续差异演化（与旧版结构保持一致）。
///
/// - **分页数据**：首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收，
///   委托给 `MessageListPaginationService`。
/// - **行合并**：真实落库消息 + 状态行，委托给 `MessageListRowBuilder`。
/// - **渲染器分发**：View 直接从 `MessageRenderingProviding` 获取渲染器，
///   并透传 `verbosity`，本 viewmodel 不参与渲染。
@MainActor
final class ListV3ViewModel: ObservableObject {
    /// 流式逐字显示开关。
    static var streamingDisplayEnabled = false

    // MARK: - Published State (供 View 展示)

    /// 稳定历史展示行：落库消息快照/结构化插入消息 + 状态行。
    @Published private(set) var historyRows: [Message] = []

    /// 流式临时行（独立于历史行）。语义同 V2；详见 `ListV2ViewModel.streamingRow`。
    @Published private(set) var streamingRow: Message?
    @Published private(set) var activityMessage: Message?

    /// 内存中的真实落库消息（分页窗口），按时间升序；`hasPersistedMessages` 由它派生。
    @Published private(set) var persistedMessages: [Message] = [] {
        didSet { rebuildHistoryRows() }
    }

    /// 顶部是否还有更早的消息未加载。
    @Published private(set) var hasEarlierMessages = false
    /// 首屏 loading：切换会话时为 true，首屏数据就绪后置 false。
    @Published private(set) var isLoading = true
    /// 正在加载更早一页（View 分页按钮的 loading 态）。
    @Published private(set) var isLoadingEarlier = false

    /// V1 (brief) 模式下应**默认展开**的工具步骤组（助手消息 id）集合。
    /// 当前策略是所有步骤组默认收起，因此该集合保持为空。
    @Published private(set) var activeStepGroupMessageIDs: Set<UUID> = []

    /// ToolManager-backed summaries keyed by AgentTurn ID。
    @Published private(set) var turnActivitySummaries: [UUID: LumiTurnActivitySummary] = [:]

    /// 最近一次当前会话的用户消息插入，用于让 View 在用户发送后滚到底部。
    @Published private(set) var latestUserMessageID: UUID?

    // MARK: - Dependencies & Internal State

    private let services: MessageListServices
    private let pagination = MessageListPaginationService()
    private let rowBuilder = MessageListRowBuilder()
    private let tailRefreshGate = MessageListTailRefreshGate()

    /// 切换会话时记录的目标会话，用于丢弃过期的后台读结果。
    private var activeConversationID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    /// objectWillChange remains a compatibility fallback for updates/deletes.
    private var pendingInsertionFallbacksToSkip = 0
    private var didBindServices = false
    /// 流式服务是否已订阅；尚未就绪时由 `activate` 重试。
    private var didBindStreaming = false
    /// 单飞帧门禁：把逐 token 广播合并成每帧（~16ms）最多一次刷新。
    private var streamingRefreshTask: Task<Void, Never>?
    /// 流式行上次的可见性（nil↔非 nil），用于在切换时重算历史行。
    private var streamingRowWasVisible = false
    /// Signature of the inputs used to build the last `historyRows`。
    private var lastHistoryBuildSignature: HistoryBuildSignatureV3?

    init(services: MessageListServices) {
        self.services = services
    }

    // MARK: - Read-only Accessors (View 展示用)

    var selectedConversationID: UUID? {
        services.selectedConversationID
    }

    /// 内存中是否已有真实落库消息；供 View 判断空态（流式/状态行不算）。
    var hasPersistedMessages: Bool {
        !persistedMessages.isEmpty
    }

    /// 当前会话的响应详细程度；由 View 透传给渲染闭包。
    var verbosity: ResponseVerbosity {
        services.verbosity(for: selectedConversationID)
    }

    func renderer(for message: Message) -> MessageRendererItem? {
        services.rendering?.renderer(for: message)
    }

    /// Loads the display snapshot for one AgentTurn.
    func turnActivity(for turnID: UUID, conversationID: UUID) async -> LumiTurnActivity? {
        guard let toolManager = services.toolManager else { return nil }
        let records = await toolManager.toolCalls(for: turnID)
        let state = services.agentTurn?.state(for: conversationID) ?? .idle
        return TurnActivityBuilder.build(
            turnID: turnID,
            conversationID: conversationID,
            state: state,
            toolCalls: records
        )
    }

    // MARK: - Lifecycle

    /// 切换/进入会话：绑定服务订阅（幂等），记录目标会话，加载最近一页。
    func activate(conversationID: UUID?) async {
        bindServicesIfNeeded()
        activeConversationID = conversationID
        latestUserMessageID = nil
        // 切换会话：清掉上一会话的流式行残留。
        streamingRow = nil
        activityMessage = services.activityMessage(for: conversationID)
        streamingRowWasVisible = false
        isLoading = true
        await loadFirstPage(conversationID: conversationID)
        if let conversationID {
            await refreshTurnActivitySummaries(conversationID: conversationID)
        } else {
            turnActivitySummaries = [:]
        }
    }

    /// 会话设置（verbosity 等）变化后的轻量刷新。
    func refreshConversationSettingsIfNeeded() {
        rebuildHistoryRows()
    }

    // MARK: - Pagination

    /// 向上翻页：加载更早一页并 prepend，触发窗口回收。
    /// - Returns: prepend 前最早一条消息的 id，View 应把它钉回视口顶部。
    func loadEarlier(isAtBottom: Bool) async -> UUID? {
        guard let conversationID = selectedConversationID,
              !isLoadingEarlier,
              let currentFirstID = persistedMessages.first?.id else { return nil }
        isLoadingEarlier = true
        defer { isLoadingEarlier = false }
        guard let result = await pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: services.messages,
            currentFirstID: currentFirstID,
            hasEarlier: hasEarlierMessages
        ) else { return nil }
        // 加载期间用户可能切了会话，丢弃过期结果。
        guard selectedConversationID == conversationID else { return nil }
        persistedMessages = result.earlier + persistedMessages
        hasEarlierMessages = result.hasEarlierMessages
        persistedMessages = pagination.evictTailIfNeeded(
            messages: persistedMessages, isAtBottom: isAtBottom
        )
        return result.anchorID
    }

    /// 尾部刷新：重新查最近一页，与当前尾部比对并覆盖（新消息到达 / 流式落库）。
    @discardableResult
    func refreshTail() async -> Bool {
        await tailRefreshGate.run { [weak self] in
            guard let self else { return false }
            return await self.performTailRefresh()
        }
    }

    /// Performs one tail snapshot read. The gate above guarantees this method
    /// is never active more than once and requests arriving during I/O receive
    /// one trailing pass before the owner returns.
    private func performTailRefresh() async -> Bool {
        guard let conversationID = selectedConversationID else { return false }
        guard let result = await pagination.refreshTail(
            conversationID: conversationID,
            messageManager: services.messages,
            current: persistedMessages
        ) else { return false }
        guard selectedConversationID == conversationID else { return false }

        let messagesChanged = persistedMessages != result.merged
        let hasEarlierChanged = result.hasEarlierMessages.map { $0 != hasEarlierMessages } ?? false
        guard messagesChanged || hasEarlierChanged else { return false }

        if messagesChanged {
            persistedMessages = result.merged
        }
        if let hasEarlier = result.hasEarlierMessages, hasEarlierChanged {
            hasEarlierMessages = hasEarlier
        }
        if messagesChanged {
            await refreshTurnActivitySummaries(conversationID: conversationID)
        }
        return messagesChanged
    }

    // MARK: - Private

    /// 首屏：加载最近一页，并探测是否还有更早消息。
    private func loadFirstPage(conversationID: UUID?) async {
        guard let conversationID else {
            persistedMessages = []
            hasEarlierMessages = false
            isLoading = false
            return
        }
        let result = await pagination.loadFirstPage(
            conversationID: conversationID,
            messageManager: services.messages
        )
        // 切换会话期间用户可能又选了别的会话，丢弃过期结果。
        guard selectedConversationID == conversationID else { return }
        persistedMessages = result.messages
        hasEarlierMessages = result.hasEarlierMessages
        isLoading = false
    }

    /// Refreshes only the turns represented by the current message window.
    private func refreshTurnActivitySummaries(conversationID: UUID) async {
        guard let toolManager = services.toolManager else {
            if !turnActivitySummaries.isEmpty {
                turnActivitySummaries = [:]
            }
            return
        }
        let turnIDs = Set(
            persistedMessages
                .filter { $0.conversationID == conversationID }
                .compactMap(\.turnID)
        )
        guard !turnIDs.isEmpty else {
            if !turnActivitySummaries.isEmpty {
                turnActivitySummaries = [:]
            }
            return
        }

        var summaries: [UUID: LumiTurnActivitySummary] = [:]
        for turnID in turnIDs {
            let records = await toolManager.toolCalls(for: turnID)
            let durations = records.compactMap(\.duration)
            summaries[turnID] = LumiTurnActivitySummary(
                turnID: turnID,
                totalCount: records.count,
                completedCount: records.filter { $0.completedAt != nil }.count,
                failedCount: records.filter(\.resultIsError).count,
                totalDuration: durations.isEmpty ? nil : durations.reduce(0, +)
            )
        }
        guard selectedConversationID == conversationID else { return }
        if turnActivitySummaries != summaries {
            turnActivitySummaries = summaries
        }
    }

    /// 订阅发送服务 / 流式服务的窄播（绕开全局广播），变化时重算展示行。
    /// 语义与实现同 V2；详见 `ListV2ViewModel.bindServicesIfNeeded`。
    private func bindServicesIfNeeded() {
        guard !didBindServices else { return }
        if let messages = services.messages {
            messageChangeObserver = messages.addMessageChangeObserver { [weak self] change in
                self?.handleMessageChange(change)
            }
            messages.objectWillChange
                .map { _ in () }
                .eraseToAnyPublisher()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    if self.consumePendingInsertionFallback() {
                        return
                    }
                    Task { @MainActor [weak self] in
                        await self?.refreshTail()
                    }
                }
                .store(in: &cancellables)
        }
        if let state = services.conversationState {
            state.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.activityMessage = self.services.activityMessage(for: self.selectedConversationID)
                }
                .store(in: &cancellables)
        }
        // 发送状态不触发历史尾部刷新；activity 由 conversationState 单独更新。
        didBindServices = services.messages != nil || services.conversationState != nil

        // 流式逐字显示：订阅 streaming，帧门禁合并。详见 V2。
        guard !didBindStreaming else { return }
        guard let streaming = services.streaming else { return }
        streaming.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleStreamingRefresh()
            }
            .store(in: &cancellables)
        didBindStreaming = true
    }

    /// Applies an insertion directly from the in-memory message event.
    private func handleMessageChange(_ change: MessageChange) {
        guard case let .inserted(message, conversationID) = change else { return }
        pendingInsertionFallbacksToSkip += 1
        guard conversationID == selectedConversationID,
              message.role != .tool else { return }

        if message.role == .user {
            latestUserMessageID = message.id
        }

        var next = persistedMessages
        if let index = next.firstIndex(where: { $0.id == message.id }) {
            next[index] = message
        } else {
            next.append(message)
            next.sort {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt < $1.createdAt
            }
        }
        if next.count > pagination.maxRetainedCount {
            next.removeFirst(next.count - pagination.maxRetainedCount)
        }
        persistedMessages = next
    }

    /// Consumed by the ViewModel's objectWillChange compatibility path.
    private func consumePendingInsertionFallback() -> Bool {
        guard pendingInsertionFallbacksToSkip > 0 else { return false }
        pendingInsertionFallbacksToSkip -= 1
        return true
    }

    /// 帧门禁：把逐 token 的流式广播合并成每帧（~16ms）最多一次刷新。
    private func scheduleStreamingRefresh() {
        guard streamingRefreshTask == nil else { return }
        streamingRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, let self else { return }
            self.streamingRefreshTask = nil
            self.applyStreamingState()
        }
    }

    /// 从流式服务读取当前状态，更新 `streamingRow`。可见性规则同 V2。
    private func applyStreamingState() {
        guard Self.streamingDisplayEnabled, verbosity != .brief else {
            updateStreamingRow(nil)
            return
        }
        guard let streaming = services.streaming,
              let conversationID = selectedConversationID else {
            updateStreamingRow(nil)
            return
        }
        let stage = streaming.stage(for: conversationID)
        let row = streaming.streamingMessage(for: conversationID)
        if (stage == .thinking || stage == .generating), let row,
           row.conversationID == conversationID {
            updateStreamingRow(row)
        } else {
            updateStreamingRow(nil)
        }
        activityMessage = streamingRow == nil
            ? services.activityMessage(for: conversationID)
            : nil
    }

    /// 更新流式行，并在可见性切换（nil↔非 nil）时重算历史行（隐藏/恢复 status 行）。
    private func updateStreamingRow(_ row: Message?) {
        let nowVisible = row != nil
        streamingRow = row
        if nowVisible != streamingRowWasVisible {
            streamingRowWasVisible = nowVisible
            rebuildHistoryRows()
        }
    }

    /// Rebuilds only stable history rows from persisted messages. History rows
    /// are database-driven; the only streaming influence is `hidesStatus`.
    private func rebuildHistoryRows() {
        let verbosity = self.verbosity
        let conversationID = selectedConversationID
        let hidesStatus = streamingRow != nil
        let signature = HistoryBuildSignatureV3(
            conversationID: conversationID,
            verbosity: verbosity,
            hidesStatus: hidesStatus,
            fingerprints: persistedMessages.map {
                MessageFingerprintV3(
                    id: $0.id,
                    contentLength: $0.content.count,
                    role: $0.role,
                    isToolExecutionOnly: $0.isToolExecutionOnly,
                    toolCallResultState: $0.toolCalls?.map {
                        let result = $0.result
                        let resultState = result.map {
                            "\($0.content.count):\($0.awaitingUserResponse == true)"
                        } ?? "nil"
                        return "\($0.id):\(resultState)"
                    } ?? []
                )
            }
        )

        guard signature != lastHistoryBuildSignature else { return }
        lastHistoryBuildSignature = signature
        let rows = rowBuilder.buildHistory(
            persisted: persistedMessages,
            conversationID: conversationID,
            verbosity: verbosity,
            hidesStatus: hidesStatus
        )
        if historyRows != rows {
            historyRows = rows
        }
    }
}
