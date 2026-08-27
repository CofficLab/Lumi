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
private struct HistoryBuildSignature: Equatable {
    let conversationID: UUID?
    let verbosity: ResponseVerbosity
    /// 流式行可见性翻转时 status 行显隐不同，需纳入签名以触发重算。
    let hidesStatus: Bool
    /// Per persisted message — captures additions/removals/reordering AND
    /// content edits while staying far cheaper than comparing full content strings.
    let fingerprints: [MessageFingerprint]
}

private struct MessageFingerprint: Equatable {
    let id: UUID
    let contentLength: Int
    let role: MessageRole
    let isToolExecutionOnly: Bool
    /// 工具结果写回 assistant 消息时 content 本身可能不变，必须纳入
    /// 指纹，否则历史行会继续持有 result == nil 的旧快照。
    let toolCallResultState: [String]
}

/// Message List View Model (V2 / standard)
///
/// 消息列表 UI 的**视图模型**：持有全部视图状态（`historyRows`/`isLoading`/分页窗口），
/// 把数据层服务合并成可直接展示的行序列，让 `ListV2View` 只负责纯展示与滚动。
///
/// **历史行纯数据库驱动 + 流式行独立**：`historyRows` 只来源于落库消息，
/// 经 `HistoryBuildSignature`（含 contentLength）短路避免高频重建。流式临时行
/// （`streamingRow`）是**独立** published 属性，用稳定 id `LumiStreamingRowID` ——
/// token 增长只让 SwiftUI diff 这一行，不触发 `historyRows` 全量 rebuild，
/// 从根上避免流式 token 高频重建富文本导致的 AttributeGraph 活锁。流式行可见时，
/// 历史里的 `.status` 行（"正在思考…"）被隐藏（由 `rebuildHistoryRows` 的
/// `hidesStatus` 控制）。
///
/// - **分页数据**：首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收，
///   委托给 `MessageListPaginationService`。
/// - **行合并**：真实落库消息 + 状态行，委托给 `MessageListRowBuilder`。
/// - **渲染器分发**：View 直接从 `MessageRenderingProviding` 获取渲染器，
///   并透传 `verbosity`，本 viewmodel 不参与渲染。
///
/// 事件感知（新版无 `.lumiMessagesDidChange` 通知，全部改为订阅 Provider 的
/// `objectWillChange` 窄播）：`messages` 落库变化、`sender` 发送状态、`streaming`
/// 流式 token、`toolManager` 工具活动。
@MainActor
final class ListV2ViewModel: ObservableObject {
    /// 流式逐字显示开关。
    static var streamingDisplayEnabled = false

    // MARK: - Published State (供 View 展示)

    /// 稳定历史展示行：真实落库消息 + 状态行，纯数据库驱动。
    @Published private(set) var historyRows: [Message] = []

    /// 流式临时行（独立于历史行）。仅在 thinking/generating 阶段非 nil。
    @Published private(set) var streamingRow: Message?

    /// 内存中的真实落库消息（分页窗口），按时间升序；`hasPersistedMessages` 由它派生。
    @Published private(set) var persistedMessages: [Message] = [] {
        didSet {
            rebuildHistoryRows()
            warmMarkdownRenderCaches()
        }
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

    // MARK: - Dependencies & Internal State

    private let services: MessageListServices
    private let pagination = MessageListPaginationService()
    private let rowBuilder = MessageListRowBuilder()
    private let tailRefreshGate = MessageListTailRefreshGate()

    /// 切换会话时记录的目标会话，用于丢弃过期的后台读结果。
    private var activeConversationID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    private var didBindServices = false
    private var didBindStreaming = false
    /// 单飞帧门禁：把逐 token 的 `objectWillChange` 广播合并成每帧（~16ms）最多一次刷新。
    private var streamingRefreshTask: Task<Void, Never>?
    /// 流式行上次的可见性（nil↔非 nil），用于在切换时重算历史行（隐藏/恢复 status 行）。
    private var streamingRowWasVisible = false
    /// Signature of the inputs used to build the last `historyRows`。
    private var lastHistoryBuildSignature: HistoryBuildSignature?

    /// 已预热过 Markdown 块级缓存的消息 id。
    private var warmedMarkdownMessageIDs: Set<UUID> = []

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
        // 切换会话：清掉上一会话的流式行残留，并重置可见性记忆。
        streamingRow = nil
        streamingRowWasVisible = false
        isLoading = true
        loadFirstPage(conversationID: conversationID)
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
        guard let result = pagination.loadEarlier(
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
        guard let result = pagination.refreshTail(
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
    private func loadFirstPage(conversationID: UUID?) {
        guard let conversationID else {
            persistedMessages = []
            hasEarlierMessages = false
            isLoading = false
            return
        }
        let result = pagination.loadFirstPage(
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
    ///
    /// 历史行仍是**纯数据库驱动**：落库消息由 `messages.objectWillChange` →
    /// `refreshTail()` 路径刷新（替代旧版 `.lumiMessagesDidChange` 通知），
    /// `refreshTurnActivitySummaries` 也随之更新（新版 `ToolManagerProviding`
    /// 协议无 objectWillChange 通道，工具活动摘要只在消息落库时刷新）。
    /// 流式逐字显示通过独立订阅 `streaming.objectWillChange` 实现：
    /// 逐 token 广播经帧门禁（`scheduleStreamingRefresh`）合并成每帧最多一次刷新，
    /// 只更新独立的 `streamingRow`，不触碰 `historyRows`（避免活锁）。
    ///
    /// `receive(on:)` 让 sink 在属性写入完成后异步执行
    /// （objectWillChange 在 willSet 触发，同步读取会拿到旧值）。
    /// 幂等：sender / streaming 各绑定一次；尚未就绪时由下次 `activate` 重试。
    private func bindServicesIfNeeded() {
        guard !didBindServices else { return }
        if let messages = services.messages {
            // 落库消息变化（新增/编辑/删除，任意会话）：统一走合并的 tail-refresh 路径。
            messages.objectWillChange
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
        if let sender = services.sender {
            // Sending churns at high frequency during a turn（status/queue 更新）。
            // 路由 sender 变化走同一个合并的 tail-refresh 路径。
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
        didBindServices = services.messages != nil || services.sender != nil

        // 流式逐字显示：订阅 streaming 的 objectWillChange，用帧门禁合并。
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

    /// 帧门禁：把逐 token 的流式广播合并成每帧（~16ms）最多一次刷新。
    /// 已有挂起任务时直接返回（丢弃本次广播），否则新建一个睡 16ms 的任务，
    /// 醒来后从 store 读取最新的流式行/阶段并更新 `streamingRow`。
    private func scheduleStreamingRefresh() {
        guard streamingRefreshTask == nil else { return }
        streamingRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, let self else { return }
            self.streamingRefreshTask = nil
            self.applyStreamingState()
        }
    }

    /// 从流式服务读取当前状态，更新 `streamingRow`。
    /// 可见性规则：stage == .thinking/.generating 且 row 非空 → 显示；否则隐藏。
    /// brief 模式与运行时开关关闭时永远隐藏。
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
    }

    /// 更新流式行，并在可见性切换（nil↔非 nil）时重算历史行（隐藏/恢复 status 行）。
    private func updateStreamingRow(_ row: Message?) {
        let nowVisible = row != nil
        streamingRow = row
        if nowVisible != streamingRowWasVisible {
            streamingRowWasVisible = nowVisible
            // 可见性翻转：历史行里的 .status 行需要相应隐藏/恢复。
            rebuildHistoryRows()
        }
    }

    /// Rebuilds only stable history rows from persisted messages. History rows
    /// are database-driven; the only streaming influence is `hidesStatus`.
    /// Short-circuits on a cheap input signature: when the persisted window,
    /// verbosity and hidesStatus are unchanged since the last build, the full
    /// projection + O(rows × content) array comparison is skipped.
    private func rebuildHistoryRows() {
        let verbosity = self.verbosity
        let conversationID = selectedConversationID
        let hidesStatus = streamingRow != nil
        let signature = HistoryBuildSignature(
            conversationID: conversationID,
            verbosity: verbosity,
            hidesStatus: hidesStatus,
            fingerprints: persistedMessages.map {
                MessageFingerprint(
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

    /// 会话加载/翻页后，把窗口内新出现的消息内容在后台线程预热进
    /// KitMarkdown 块级缓存（utility 优先级，不与 UI 抢资源）。
    ///
    /// 动机：`List` 是惰性容器，滚动到未物化过的行时才首次解析该行内容；
    /// 预热后 `MarkdownBlockRenderer.init` 的同步缓存查询命中，行首帧即有
    /// 内容与测量高度 —— 不触发主线程解析，也无"留空 → 填充"的高度跳变。
    private func warmMarkdownRenderCaches() {
        let pending = persistedMessages.filter {
            !$0.content.isEmpty && !warmedMarkdownMessageIDs.contains($0.id)
        }
        guard !pending.isEmpty else { return }

        // 防止长会话/多会话切换下集合无界增长；重置后重复预热只是近免费的缓存查询
        if warmedMarkdownMessageIDs.count > 2_000 {
            warmedMarkdownMessageIDs.removeAll()
        }
        let contents = pending.map(\.content)
        pending.forEach { warmedMarkdownMessageIDs.insert($0.id) }

        Task.detached(priority: .utility) {
            for content in contents {
                MarkdownRenderCache.warm(markdown: content)
            }
        }
    }
}

/// ToolManager-backed per-turn activity summary（统计视图使用）。
struct LumiTurnActivitySummary: Equatable, Sendable {
    let turnID: UUID
    let totalCount: Int
    let completedCount: Int
    let failedCount: Int
    let totalDuration: TimeInterval?

    init(
        turnID: UUID,
        totalCount: Int,
        completedCount: Int,
        failedCount: Int,
        totalDuration: TimeInterval?
    ) {
        self.turnID = turnID
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.totalDuration = totalDuration
    }
}
