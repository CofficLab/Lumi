import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// Cheap fingerprint of the inputs that decide `MessageListRowBuilder.buildHistory`
/// output, used to skip the (O(rows × content) memberwise) `historyRows` array
/// comparison when nothing relevant changed between calls.
private struct HistoryBuildSignature: Equatable {
    let conversationID: UUID?
    let verbosity: LumiResponseVerbosity
    let streamingStage: ChatStage
    let hasStreamingRow: Bool
    /// Per persisted message — captures additions/removals/reordering AND
    /// content edits while staying far cheaper than comparing full content
    /// strings.
    let fingerprints: [MessageFingerprint]
}

private struct MessageFingerprint: Equatable {
    let id: UUID
    let contentLength: Int
    let role: LumiChatMessageRole
    let isToolExecutionOnly: Bool
}

/// Message List View Model
///
/// 消息列表 UI 的**视图模型**:持有全部视图状态(`displayRows`/`isLoading`/分页窗口),
/// 把数据层服务(`MessageManaging`/`MessageStreaming`/`MessageSending`)合并成可直接
/// 展示的行序列,让 `MessageListView` 只负责纯展示与滚动。
///
/// - **分页数据**:首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收,
///   委托给 `MessageListPaginationService`,本类只持有状态与过期结果丢弃判定。
/// - **行合并**:真实消息 + 流式临时行 + 发送中状态行,委托给
///   `MessageListRowBuilder`;View 只面对已准备好的 `displayRows`,不区分行的来源。
/// - **渲染器分发**:View 直接从 `kernel.messageRendererManager` 获取渲染器,
///   并透传 `verbosity`,本 viewmodel 不参与渲染。
///
/// 流式/发送服务的变化通过**窄播订阅**(直接订阅服务的 objectWillChange)
/// 触发展示行重算,绕开 kernel 的全局 objectWillChange 广播 ——
/// 流式期间 viewmodel 每个 token 都更新,若经 kernel 广播会拖慢整个 app。
///
/// - SeeAlso: `MessageListPaginationService`(分页策略)、
///   `MessageListRowBuilder`(行合并规则)。
@MainActor
final class ListViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-list.viewmodel")
    nonisolated static let emoji = "📜"
    nonisolated static let verbose = false

    // MARK: - Published State (供 View 展示)

    /// 稳定历史展示行:真实消息 + 状态行,不包含高频变化的流式尾部。
    @Published private(set) var historyRows: [LumiChatMessage] = []

    /// 当前会话的流式尾部。token 到达时只更新这一行,不重建 historyRows。
    @Published private(set) var streamingRow: LumiChatMessage?

    /// 内存中的真实落库消息(分页窗口),按时间升序;`hasPersistedMessages` 由它派生。
    /// 任何变更都会触发历史行重算,流式尾部单独维护。
    @Published private(set) var persistedMessages: [LumiChatMessage] = [] {
        didSet { rebuildHistoryRows() }
    }

    /// 顶部是否还有更早的消息未加载。
    @Published private(set) var hasEarlierMessages = false
    /// 首屏 loading:切换会话时为 true,首屏数据就绪后置 false。
    @Published private(set) var isLoading = true
    /// 正在加载更早一页(View 分页按钮的 loading 态)。
    @Published private(set) var isLoadingEarlier = false
    /// 当前流式行正文;View 监听它做"用户停在底部时的跟随滚动"。
    /// 内容未变时不发布,避免无意义的重估。
    @Published private(set) var tailStreamingContent: String?

    /// V1 (brief) 模式下应**默认展开**的工具步骤组(助手消息 id)集合。
    ///
    /// 当前策略是所有步骤组默认收起,因此该集合保持为空。
    /// 由 View 经 `\.lumiActiveToolGroupIDs` Environment 注入渲染层。
    @Published private(set) var activeStepGroupMessageIDs: Set<UUID> = []

    /// ToolManager-backed summaries keyed by AgentTurn ID.
    @Published private(set) var turnActivitySummaries: [UUID: LumiTurnActivitySummary] = [:]

    // MARK: - Dependencies & Internal State

    private let kernel: LumiKernel
    private let pagination = MessageListPaginationService()
    private let rowBuilder = MessageListRowBuilder()
    private let tailRefreshGate = MessageListTailRefreshGate()

    /// 切换会话时记录的目标会话,用于丢弃过期的后台读结果。
    private var activeConversationID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    /// Coalesces bursts of provider chunks to one UI update per display frame.
    private var streamingRefreshTask: Task<Void, Never>?
    private var didBindToolActivityNotifications = false
    /// 流式/发送服务是否都已绑定;服务后就绪时由 `activate` 重试绑定。
    private var didBindServices = false
    /// Signature of the inputs used to build the last `historyRows`. When the
    /// next `rebuildHistoryRows` call sees the same signature, the (expensive,
    /// O(rows × content) memberwise) array comparison is skipped entirely.
    private var lastHistoryBuildSignature: HistoryBuildSignature?

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    // MARK: - Read-only Accessors (View 展示用)

    var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    /// 内存中是否已有真实落库消息;供 View 判断空态
    /// (流式/状态行不算 —— 空态语义基于真实历史)。
    var hasPersistedMessages: Bool {
        !persistedMessages.isEmpty
    }

    /// Compatibility snapshot for scroll setup and non-rendering callers.
    /// The main message view renders `historyRows` and `streamingRow` separately.
    var displayRows: [LumiChatMessage] {
        historyRows + (streamingRow.map { [$0] } ?? [])
    }

    /// Whether the message list currently contains a live streaming turn.
    ///
    /// Static history can use a virtualized `LazyVStack`. During streaming we
    /// keep the existing eager stack for now because the streaming row changes
    /// at token frequency; the streaming/history split can be refined later
    /// without making static history pay that cost.
    var isStreaming: Bool {
        guard let streaming = kernel.messageStreaming,
              let conversationID = selectedConversationID else { return false }
        return streaming.streamingStage(for: conversationID) != .idle
            || streaming.streamingRow(for: conversationID) != nil
    }

    /// 当前会话的响应详细程度;由 View 透传给渲染闭包,
    /// 渲染器可据此切换简洁/标准/详细外观。
    var verbosity: LumiResponseVerbosity {
        kernel.conversationManager?
            .verbosity(for: selectedConversationID) ?? .defaultVerbosity
    }

    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? {
        kernel.messageRendererManager?.renderer(for: message)
    }

    /// Loads the display snapshot for one AgentTurn.
    ///
    /// ToolManager owns persistence and filtering; the message-list layer only
    /// combines those records with the current AgentTurn lifecycle state.
    func turnActivity(for turnID: UUID, conversationID: UUID) async -> LumiTurnActivity? {
        guard let toolManager = kernel.toolManager else { return nil }
        let records = await toolManager.toolCalls(for: turnID)
        let state = kernel.agentTurnManager?.state(for: conversationID) ?? .idle
        return TurnActivityBuilder.build(
            turnID: turnID,
            conversationID: conversationID,
            state: state,
            toolCalls: records
        )
    }

    // MARK: - Lifecycle

    /// 切换/进入会话:绑定服务订阅(幂等),记录目标会话,加载最近一页。
    func activate(conversationID: UUID?) async {
        if Self.verbose {
            Self.logger.info("\(self.t)激活会话：\(conversationID?.uuidString ?? "nil")")
        }
        bindServicesIfNeeded()
        activeConversationID = conversationID
        isLoading = true
        await loadFirstPage(conversationID: conversationID)
        if Self.verbose {
            Self.logger.info("\(self.t)首屏加载完成,persistedMessages: \(self.persistedMessages.count)")
        }
        if let conversationID {
            await refreshTurnActivitySummaries(conversationID: conversationID)
        } else {
            turnActivitySummaries = [:]
        }
    }

    /// 会话设置(verbosity 等)变化后的轻量刷新。
    ///
    /// 由 `.lumiConversationsDidChange` 驱动(切换 verbosity 等会广播该事件)。
    /// `rebuildHistoryRows` 的 signature 内含 verbosity,未变化时 O(rows) 比较后
    /// 直接跳过,因此该事件即使被高频触发(如消息活跃标记)也无碍。
    func refreshConversationSettingsIfNeeded() {
        rebuildHistoryRows()
    }

    // MARK: - Pagination

    /// 向上翻页:加载更早一页并 prepend,触发窗口回收。
    ///
    /// - Parameter isAtBottom: 用户是否在底部(窗口回收策略需要,由 View 传入)。
    /// - Returns: prepend 前最早一条消息的 id,View 应把它钉回视口顶部;
    ///   `nil` 表示无需操作。
    func loadEarlier(isAtBottom: Bool) async -> UUID? {
        guard let conversationID = selectedConversationID,
              !isLoadingEarlier,
              let currentFirstID = persistedMessages.first?.id else { return nil }
        isLoadingEarlier = true
        defer { isLoadingEarlier = false }
        guard let result = await pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: kernel.messageManager,
            currentFirstID: currentFirstID,
            hasEarlier: hasEarlierMessages
        ) else { return nil }
        // 加载期间用户可能切了会话,丢弃过期结果。
        guard selectedConversationID == conversationID else { return nil }
        persistedMessages = result.earlier + persistedMessages
        hasEarlierMessages = result.hasEarlierMessages
        persistedMessages = pagination.evictTailIfNeeded(
            messages: persistedMessages, isAtBottom: isAtBottom
        )
        return result.anchorID
    }

    /// 尾部刷新:重新查最近一页,与当前尾部比对并覆盖(新消息到达 / 流式落库)。
    ///
    /// 只作用于真实落库消息;流式临时行由流式服务独立持有,
    /// 经 `rebuildRows` 参与合并,无需任何特例处理。
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
            messageManager: kernel.messageManager,
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

    /// 首屏:加载最近一页,并探测是否还有更早消息。
    private func loadFirstPage(conversationID: UUID?) async {
        guard let conversationID else {
            persistedMessages = []
            hasEarlierMessages = false
            isLoading = false
            return
        }
        let result = await pagination.loadFirstPage(
            conversationID: conversationID,
            messageManager: kernel.messageManager
        )
        // 切换会话期间用户可能又选了别的会话,丢弃过期结果。
        guard selectedConversationID == conversationID else { return }
        persistedMessages = result.messages
        hasEarlierMessages = result.hasEarlierMessages
        isLoading = false
    }

    /// Refreshes only the turns represented by the current message window.
    /// ToolManager remains the source of truth for counts and durations; messages
    /// still provide the expandable tool rows.
    private func refreshTurnActivitySummaries(conversationID: UUID) async {
        guard let toolManager = kernel.toolManager else {
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

    /// 订阅流式/发送服务的窄播(绕开 kernel 全局广播),变化时重算展示行。
    ///
    /// `receive(on:)` 让 sink 在属性写入完成后异步执行
    /// (objectWillChange 在 willSet 触发,同步读取会拿到旧值)。
    /// 幂等:两个服务都绑定后不再重复;任一尚未就绪时由下次 `activate` 重试。
    private func bindServicesIfNeeded() {
        if !didBindToolActivityNotifications {
            NotificationCenter.default.publisher(for: .lumiToolActivityDidChange)
                .compactMap { notification in
                    notification.userInfo?["conversationID"] as? UUID
                }
                .filter { [weak self] conversationID in
                    self?.selectedConversationID == conversationID
                }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] conversationID in
                    guard let self else { return }
                    Task { await self.refreshTurnActivitySummaries(conversationID: conversationID) }
                }
                .store(in: &cancellables)
            didBindToolActivityNotifications = true
        }

        guard !didBindServices else { return }
        if let streaming = kernel.messageStreaming {
            streaming.objectWillChange
                .map { _ in () }
                .eraseToAnyPublisher()
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak streaming] _ in
                    guard let self, let streaming else { return }
                    self.scheduleStreamingPresentation(using: streaming)
                }
                .store(in: &cancellables)
        }
        if let sender = kernel.messageSender {
            // Sending churns at high frequency during a turn (status/queue
            // updates per event). Rebuilding the whole history projection on
            // every signal re-filters + re-merges all persisted messages and
            // compares two full O(rows × content) arrays. Instead, route sender
            // changes through the same coalesced tail-refresh path the message
            // notification uses: it re-reads the newest page off the main actor,
            // merges, and only mutates `persistedMessages` (→ `rebuildHistoryRows`)
            // when the tail actually changed. The gate collapses overlapping
            // signals into one active + one trailing refresh.
            sender.objectWillChange
                .map { _ in () }
                .eraseToAnyPublisher()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor [weak self] in
                        await self?.refreshTail()
                    }
                }
                .store(in: &cancellables)
        }
        didBindServices = kernel.messageStreaming != nil && kernel.messageSender != nil
    }

    /// Rebuilds only stable history rows. Streaming tokens do not enter this
    /// path unless the status/streaming boundary changes.
    ///
    /// Short-circuits on a cheap input signature: when the persisted window,
    /// verbosity, and streaming stage are unchanged since the last build, the
    /// full projection + O(rows × content) array comparison is skipped.
    private func rebuildHistoryRows() {
        let verbosity = self.verbosity
        let streaming = kernel.messageStreaming
        let conversationID = selectedConversationID
        let stage = conversationID.flatMap { streaming?.streamingStage(for: $0) } ?? .idle
        let hasStreamingRow = conversationID.flatMap { streaming?.streamingRow(for: $0) } != nil
        let signature = HistoryBuildSignature(
            conversationID: conversationID,
            verbosity: verbosity,
            streamingStage: stage,
            hasStreamingRow: hasStreamingRow,
            fingerprints: persistedMessages.map {
                MessageFingerprint(
                    id: $0.id,
                    contentLength: $0.content.count,
                    role: $0.role,
                    isToolExecutionOnly: $0.isToolExecutionOnly
                )
            }
        )

        if signature != lastHistoryBuildSignature {
            lastHistoryBuildSignature = signature
            let rows = rowBuilder.buildHistory(
                persisted: persistedMessages,
                conversationID: conversationID,
                streaming: streaming,
                verbosity: verbosity
            )
            if historyRows != rows {
                historyRows = rows
            }
        }

        refreshStreamingPresentation(using: streaming)
    }

    /// Updates only the live tail. The history list is rebuilt at most when
    /// entering/leaving the visible streaming stage.
    private func scheduleStreamingPresentation(using _: any MessageStreaming) {
        guard streamingRefreshTask == nil else { return }
        streamingRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, let self else { return }
            self.streamingRefreshTask = nil
            self.refreshStreamingPresentation(using: self.kernel.messageStreaming)
        }
    }

    private func refreshStreamingPresentation(using streaming: (any MessageStreaming)?) {
        let nextRow = rowBuilder.buildStreamingRow(
            conversationID: selectedConversationID,
            streaming: streaming
        )
        let wasShowingStreamingRow = streamingRow != nil
        let isShowingStreamingRow = nextRow != nil

        if wasShowingStreamingRow != isShowingStreamingRow {
            streamingRow = nextRow
            rebuildHistoryRowsWithoutStreamingRecursion()
        } else if streamingRow != nextRow {
            streamingRow = nextRow
        }

        let content = nextRow?.content
        if tailStreamingContent != content {
            tailStreamingContent = content
        }
        recomputeActiveStepGroups()
    }

    /// Rebuilds history without calling back into streaming presentation.
    private func rebuildHistoryRowsWithoutStreamingRecursion() {
        let rows = rowBuilder.buildHistory(
            persisted: persistedMessages,
            conversationID: selectedConversationID,
            streaming: kernel.messageStreaming,
            verbosity: verbosity
        )
        if historyRows != rows {
            historyRows = rows
        }
    }

    /// 计算 V1 下应默认展开的工具步骤组集合。
    ///
    /// 规则:仅当当前 turn 进行中(`agentTurnManager.isRunning(for:)`)时,取
    /// **最后一条 turn 边界消息**(上一轮的最终回复)之后、带工具调用的助手消息 id。
    /// turn 未进行中 → 空集合(全收起)。
    ///
    /// 依赖 `displayRows` 已是最新(`rebuildRows` 内先重算展示行再调用本方法)。
    private func recomputeActiveStepGroups() {
        let activeIDs: Set<UUID> = []
        if activeStepGroupMessageIDs != activeIDs {
            activeStepGroupMessageIDs = activeIDs
        }
    }
}
