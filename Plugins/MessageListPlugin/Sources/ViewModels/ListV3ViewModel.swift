import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// Cheap fingerprint of the inputs that decide `MessageListRowBuilder.buildHistory`
/// output, used to skip the (O(rows × content) memberwise) `historyRows` array
/// comparison when nothing relevant changed between calls.
private struct HistoryBuildSignatureV3: Equatable {
    let conversationID: UUID?
    let verbosity: LumiResponseVerbosity
    /// 流式行可见性翻转时 status 行显隐不同,需纳入签名以触发重算。
    let hidesStatus: Bool
    /// Per persisted message — captures additions/removals/reordering AND
    /// content edits while staying far cheaper than comparing full content
    /// strings.
    let fingerprints: [MessageFingerprintV3]
}

private struct MessageFingerprintV3: Equatable {
    let id: UUID
    let contentLength: Int
    let role: LumiChatMessageRole
    let isToolExecutionOnly: Bool
}

/// Message List V3 View Model (detailed / 详细模式)
///
/// 消息列表 UI 的**视图模型**:持有全部视图状态(`historyRows`/`isLoading`/分页窗口),
/// 把数据层服务(`MessageManaging`/`MessageSending`)合并成可直接展示的行序列,
/// 让 `MessageListView` 只负责纯展示与滚动。
///
/// **历史行纯数据库驱动 + 流式行独立**:`historyRows` 只来源于落库消息,
/// 经 `HistoryBuildSignatureV3`(含 contentLength)短路避免高频重建。流式临时行
/// (`streamingRow`)是**独立** published 属性,用稳定 id `LumiStreamingRowID` ——
/// token 增长只让 SwiftUI diff 这一行,不触发 `historyRows` 全量 rebuild,
/// 从根上避免流式 token 高频重建富文本导致的 AttributeGraph 活锁。流式行可见时,
/// 历史里的 `.status` 行被隐藏。V3(detailed)额外显示思考内容(`reasoningContent`),
/// thinking 阶段流式行的 reasoningContent 增长由 `MarkdownBlockRenderer` 增量解析。
///
/// 与 V2 的差异:V3(detailed)会**显示思考内容**(`reasoningContent`),
/// V2(standard)不显示。本类当前是 V2 的复制(行为暂与 V2 一致),
/// 思考内容显示逻辑后续在此基础上增量加入,独立于 V2 viewmodel。
///
/// - **分页数据**:首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收,
///   委托给 `MessageListPaginationService`,本类只持有状态与过期结果丢弃判定。
/// - **行合并**:真实落库消息 + 状态行,委托给 `MessageListRowBuilder`;
///   View 只面对已准备好的 `historyRows`,不区分行的来源。
/// - **渲染器分发**:View 直接从 `kernel.messageRendererManager` 获取渲染器,
///   并透传 `verbosity`,本 viewmodel 不参与渲染。
///
/// - SeeAlso: `MessageListPaginationService`(分页策略)、
///   `MessageListRowBuilder`(行合并规则)、`ListV2ViewModel`(V2 对应物)。
@MainActor
final class ListV3ViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-list.viewmodel.v3")
    nonisolated static let emoji = "🗂️"
    nonisolated static let verbose = false

    /// 流式逐字显示的运行时开关。默认开启;与 V2 共用同一 UserDefaults 键。
    nonisolated static var streamingDisplayEnabled: Bool {
        UserDefaults.standard.object(forKey: "lumiStreamingDisplayEnabled") as? Bool ?? true
    }

    // MARK: - Published State (供 View 展示)

    /// 稳定历史展示行:真实落库消息 + 状态行,纯数据库驱动。
    @Published private(set) var historyRows: [LumiChatMessage] = []

    /// 流式临时行(独立于历史行)。语义同 V2;详见 `ListV2ViewModel.streamingRow`。
    @Published private(set) var streamingRow: LumiChatMessage?

    /// 内存中的真实落库消息(分页窗口),按时间升序;`hasPersistedMessages` 由它派生。
    /// 任何变更都会触发历史行重算。
    @Published private(set) var persistedMessages: [LumiChatMessage] = [] {
        didSet { rebuildHistoryRows() }
    }

    /// 顶部是否还有更早的消息未加载。
    @Published private(set) var hasEarlierMessages = false
    /// 首屏 loading:切换会话时为 true,首屏数据就绪后置 false。
    @Published private(set) var isLoading = true
    /// 正在加载更早一页(View 分页按钮的 loading 态)。
    @Published private(set) var isLoadingEarlier = false

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
    private var didBindToolActivityNotifications = false
    /// 发送服务是否已绑定;尚未就绪时由 `activate` 重试绑定。
    private var didBindServices = false
    /// 流式服务是否已订阅;尚未就绪时由 `activate` 重试。
    private var didBindStreaming = false
    /// 单飞帧门禁:把逐 token 广播合并成每帧(~16ms)最多一次刷新。
    private var streamingRefreshTask: Task<Void, Never>?
    /// 流式行上次的可见性(nil↔非 nil),用于在切换时重算历史行。
    private var streamingRowWasVisible = false
    /// Signature of the inputs used to build the last `historyRows`. When the
    /// next `rebuildHistoryRows` call sees the same signature, the (expensive,
    /// O(rows × content) memberwise) array comparison is skipped entirely.
    private var lastHistoryBuildSignature: HistoryBuildSignatureV3?

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
        // 切换会话:清掉上一会话的流式行残留。
        streamingRow = nil
        streamingRowWasVisible = false
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

    /// 订阅工具活动 / 发送服务 / 流式服务的窄播(绕开 kernel 全局广播)。
    ///
    /// 历史行仍是纯数据库驱动。流式逐字显示通过独立订阅
    /// `messageStreaming.objectWillChange` + 帧门禁实现,只更新独立的
    /// `streamingRow`,不触碰 `historyRows`。详见 V2 同名方法。
    ///
    /// `receive(on:)` 让 sink 在属性写入完成后异步执行
    /// (objectWillChange 在 willSet 触发,同步读取会拿到旧值)。
    /// 幂等:tool-activity / sender / streaming 各绑定一次;尚未就绪时由下次
    /// `activate` 重试。
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
        didBindServices = kernel.messageSender != nil

        // 流式逐字显示:订阅 messageStreaming,帧门禁合并。详见 V2。
        guard !didBindStreaming else { return }
        guard let streaming = kernel.messageStreaming else { return }
        streaming.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleStreamingRefresh()
            }
            .store(in: &cancellables)
        didBindStreaming = true
    }

    /// 帧门禁:把逐 token 的流式广播合并成每帧(~16ms)最多一次刷新。
    private func scheduleStreamingRefresh() {
        guard streamingRefreshTask == nil else { return }
        streamingRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, let self else { return }
            self.streamingRefreshTask = nil
            self.applyStreamingState()
        }
    }

    /// 从流式服务读取当前状态,更新 `streamingRow`。可见性规则同 V2。
    private func applyStreamingState() {
        guard Self.streamingDisplayEnabled, verbosity != .brief else {
            updateStreamingRow(nil)
            return
        }
        guard let streaming = kernel.messageStreaming,
              let conversationID = selectedConversationID else {
            updateStreamingRow(nil)
            return
        }
        let stage = streaming.streamingStage(for: conversationID)
        let row = streaming.streamingRow(for: conversationID)
        if (stage == .thinking || stage == .generating), let row,
           row.conversationID == conversationID {
            updateStreamingRow(row)
        } else {
            updateStreamingRow(nil)
        }
    }

    /// 更新流式行,并在可见性切换(nil↔非 nil)时重算历史行(隐藏/恢复 status 行)。
    private func updateStreamingRow(_ row: LumiChatMessage?) {
        let nowVisible = row != nil
        streamingRow = row
        if nowVisible != streamingRowWasVisible {
            streamingRowWasVisible = nowVisible
            rebuildHistoryRows()
        }
    }

    /// Rebuilds only stable history rows from persisted messages. History rows
    /// are database-driven; the only streaming influence is `hidesStatus`.
    /// Triggered whenever `persistedMessages` changes or the streaming row's
    /// visibility flips nil↔non-nil.
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
                    isToolExecutionOnly: $0.isToolExecutionOnly
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
