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
/// 消息列表 UI 的**视图模型**:持有全部视图状态(`historyRows`/`isLoading`/分页窗口),
/// 把数据层服务(`MessageManaging`/`MessageSending`)合并成可直接展示的行序列,
/// 让 `MessageListView` 只负责纯展示与滚动。
///
/// **纯数据库驱动**:本 viewmodel 的唯一数据来源是落库消息(`MessageManaging`)。
/// 不再持有流式临时行 —— LLM 流式期间 UI 只显示 status 行("正在思考…"等),
/// 整段回复落库后由 `.lumiMessagesDidChange` → `refreshTail()` 路径一次性刷新。
/// 这样从根上消除「流式 token 高频重建富文本」导致的 AttributeGraph 活锁。
///
/// - **分页数据**:首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收,
///   委托给 `MessageListPaginationService`,本类只持有状态与过期结果丢弃判定。
/// - **行合并**:真实落库消息 + 状态行,委托给 `MessageListRowBuilder`;
///   View 只面对已准备好的 `historyRows`,不区分行的来源。
/// - **渲染器分发**:View 直接从 `kernel.messageRendererManager` 获取渲染器,
///   并透传 `verbosity`,本 viewmodel 不参与渲染。
///
/// - SeeAlso: `MessageListPaginationService`(分页策略)、
///   `MessageListRowBuilder`(行合并规则)。
@MainActor
final class ListV2ViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-list.viewmodel")
    nonisolated static let emoji = "📜"
    nonisolated static let verbose = false

    // MARK: - Published State (供 View 展示)

    /// 稳定历史展示行:真实落库消息 + 状态行,纯数据库驱动。
    @Published private(set) var historyRows: [LumiChatMessage] = []

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

    /// 订阅工具活动 / 发送服务的窄播(绕开 kernel 全局广播),变化时重算展示行。
    ///
    /// 列表已改为**纯数据库驱动**:不再订阅流式服务,落库消息由
    /// `.lumiMessagesDidChange` → `refreshTail()` 路径刷新;发送服务在此
    /// 同样路由到 `refreshTail`(见下),不再重建流式行。
    ///
    /// `receive(on:)` 让 sink 在属性写入完成后异步执行
    /// (objectWillChange 在 willSet 触发,同步读取会拿到旧值)。
    /// 幂等:tool-activity 与 sender 各绑定一次;sender 尚未就绪时由下次
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
    }

    /// Rebuilds only stable history rows from persisted messages. Pure
    /// database-driven —— no streaming input. Triggered whenever
    /// `persistedMessages` changes (DB tail refresh / pagination / page load).
    ///
    /// Short-circuits on a cheap input signature: when the persisted window and
    /// verbosity are unchanged since the last build, the full projection +
    /// O(rows × content) array comparison is skipped.
    private func rebuildHistoryRows() {
        let verbosity = self.verbosity
        let conversationID = selectedConversationID
        let signature = HistoryBuildSignature(
            conversationID: conversationID,
            verbosity: verbosity,
            fingerprints: persistedMessages.map {
                MessageFingerprint(
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
            verbosity: verbosity
        )
        if historyRows != rows {
            historyRows = rows
        }
    }

}
