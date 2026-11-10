import Foundation
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming

/// `MessageListRowBuilder.buildHistory` 输入的廉价指纹。
///
/// 用于在两次调用之间跳过 O(行数 × 内容) 的成员逐项比较。
private struct HistoryBuildSignature: Equatable {
    let conversationID: UUID?
    let verbosity: ResponseVerbosity
    /// 流式行可见性翻转时 status 行显隐不同，需纳入签名以触发重算。
    let hidesStatus: Bool
    /// 每条落库消息的指纹：覆盖新增/删除/重排与内容编辑。
    let fingerprints: [MessageFingerprint]
}

private struct MessageFingerprint: Equatable {
    let id: UUID
    /// 内容指纹。
    ///
    /// 用**哈希**而不是长度：等长替换（"AAAA" → "BBBB"）长度不变，按长度判定
    /// 会漏掉这种更新，历史行会继续持有旧文本。
    let contentHash: Int
    let role: MessageRole
    let isToolExecutionOnly: Bool
    let toolCallResultState: [String]
    /// 授权状态（`pendingAuthorization` → `userApproved` / `userRejected`）。
    ///
    /// 它与 `result` 一起决定渲染层要不要再弹一次授权卡片，因此必须纳入指纹。
    let toolCallAuthorizationState: [String]
}

/// V5（ChatGPT）消息列表的视图模型。
///
/// - **分页数据**：首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收，
///   委托给 `MessageListPaginationService`。
/// - **行合并**：真实落库消息 + 状态行，委托给 `MessageListRowBuilder`。
/// - **轮次投影**：委托给 `ChatGPTTurnProjectionStore`，历史变化才 O(n) 重建。
/// - **渲染器分发**：View 从能力里获取渲染器，本 viewmodel 不参与渲染。
///
/// - Important: **异步身份保护**。每个 `await` 之后都要比较
///   `activationSequence` 与 `conversationID`；不匹配就**直接返回**，
///   既不写状态也不写错误。否则旧会话的迟到结果会覆盖新会话的快照。
@MainActor
final class ChatGPTListViewModel: ObservableObject {
    /// 流式逐字显示开关。
    ///
    /// 曾是 `static` 全局开关，测试并行执行时会互相覆盖。
    /// 改为实例属性 + 构造注入后不再有共享状态。
    private let streamingDisplayEnabled: Bool

    init(
        services: MessageListServices,
        pagination: MessageListPaginationService = MessageListPaginationService(),
        projectionStore: ChatGPTTurnProjectionStore = ChatGPTTurnProjectionStore(),
        streamingDisplayEnabled: Bool = false
    ) {
        self.services = services
        self.pagination = pagination
        self.projectionStore = projectionStore
        self.streamingDisplayEnabled = streamingDisplayEnabled
    }

    // MARK: - Published State (供 View 展示)

    /// 稳定历史展示行：落库消息快照/结构化插入消息 + 状态行。
    @Published private(set) var historyRows: [Message] = []

    /// 流式临时行（独立于历史行）。
    @Published private(set) var streamingRow: Message?
    @Published private(set) var activityMessage: Message?

    /// 内存中的真实落库消息（分页窗口），按时间升序。
    @Published private(set) var persistedMessages: [Message] = [] {
        didSet { rebuildHistoryRows() }
    }

    /// 顶部是否还有更早的消息未加载。
    @Published private(set) var hasEarlierMessages = false
    /// 首屏 loading：切换会话时为 true，首屏数据就绪后置 false。
    @Published private(set) var isLoading = true
    /// 正在加载更早一页（View 分页按钮的 loading 态）。
    @Published private(set) var isLoadingEarlier = false

    /// 最近一次当前会话的用户消息插入，用于让 View 在用户发送后滚到底部。
    @Published private(set) var latestUserMessageID: UUID?

    // MARK: - Dependencies & Internal State

    private let services: MessageListServices
    private let pagination: MessageListPaginationService
    private let projectionStore: ChatGPTTurnProjectionStore
    private let rowBuilder = MessageListRowBuilder()
    private let tailRefreshGate = MessageListTailRefreshGate()

    /// 切换会话时记录的目标会话，用于丢弃过期的后台读结果。
    private var activeConversationID: UUID?
    /// 单飞帧门禁：把逐 token 事件合并成每帧（~16ms）最多一次刷新。
    private var streamingRefreshTask: Task<Void, Never>?
    /// 流式行上次的可见性（nil↔非 nil），用于在切换时重算历史行。
    private var streamingRowWasVisible = false
    /// 上次构建 `historyRows` 的输入指纹。
    private var lastHistoryBuildSignature: HistoryBuildSignature?
    /// 激活序列号，用于防止并发切换时旧的异步加载结果回写。
    private var activationSequence: UInt64 = 0

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

    /// 轮次投影快照。
    ///
    /// - Important: 历史轮次被 `ChatGPTTurnProjectionStore` 缓存，
    ///   流式更新只重建 live tail，不触发 O(n) 的历史重扫。
    var turnProjection: ChatGPTTurnProjection {
        projectionStore.snapshot(
            history: historyRows,
            streaming: streamingRow,
            activity: activityMessage
        )
    }

    func renderer(for message: Message) -> MessageRendererItem? {
        services.rendering?.renderer(for: message)
    }

    // MARK: - Lifecycle

    /// 切换/进入会话：记录目标会话并加载最近一页。
    func activate(conversationID: UUID?) async {
        // 忽略已经不是当前选择的目标。View 用 activateCurrentConversation()
        // 发起切换，因此延迟的 view 任务不会覆盖更新的会话快照。
        guard selectedConversationID == conversationID else { return }
        activationSequence &+= 1
        let mySequence = activationSequence

        activeConversationID = conversationID
        latestUserMessageID = nil
        // 切换会话：清掉上一会话的流式行残留。
        streamingRow = nil
        activityMessage = services.activityMessage(for: conversationID)
        streamingRowWasVisible = false
        persistedMessages = []
        hasEarlierMessages = false
        // 切换会话重置轮次投影与滚动身份。
        projectionStore.reset()
        lastHistoryBuildSignature = nil
        isLoading = true
        defer {
            if mySequence == activationSequence {
                isLoading = false
            }
        }
        await loadFirstPage(conversationID: conversationID, sequence: mySequence)
        guard mySequence == activationSequence,
              selectedConversationID == conversationID else { return }
    }

    /// 用任务执行时观察到的选择发起切换。
    func activateCurrentConversation() async {
        await activate(conversationID: selectedConversationID)
    }

    /// 会话设置（verbosity 等）变化后的轻量刷新。
    func refreshConversationSettingsIfNeeded() {
        rebuildHistoryRows()
    }

    // MARK: - Pagination

    /// 向上翻页：加载更早一页并 prepend，触发窗口回收。
    /// - Returns: prepend 前最早一条消息的 id，View 应把它钉回视口顶部。
    func loadEarlier() async -> UUID? {
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
        persistedMessages = pagination.evictTailIfNeeded(messages: persistedMessages)
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

    /// 执行一次尾部快照读取。上面的门禁保证本方法同时最多只有一个活动实例，
    /// 活动期间到达的请求会收到一次尾部补跑。
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
        return messagesChanged
    }

    // MARK: - Private

    /// 首屏：加载最近一页，并探测是否还有更早消息。
    private func loadFirstPage(conversationID: UUID?, sequence: UInt64) async {
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
        guard sequence == activationSequence,
              selectedConversationID == conversationID else { return }
        persistedMessages = result.messages
        hasEarlierMessages = result.hasEarlierMessages
        isLoading = false
    }

    func handleSelectedConversationChange(_ conversationID: UUID?) {
        // 在异步切换任务启动**之前**让上一个会话失效，
        // 这样快速切换不会发布过期快照。
        activationSequence &+= 1
        Task { @MainActor [weak self] in
            await self?.activate(conversationID: conversationID)
        }
    }

    func handleConversationStateChange(_ event: ConversationStateEvent) {
        guard case let .updated(conversationID) = event,
              conversationID == selectedConversationID else { return }
        activityMessage = services.activityMessage(for: conversationID)
    }

    func handleStreamingChange(_ change: MessageStreamingChange) {
        guard case let .updated(conversationID) = change,
              conversationID == selectedConversationID else { return }
        scheduleStreamingRefresh()
    }

    /// 直接应用来自内存消息事件的插入。
    func handleMessageChange(_ change: MessageChange) {
        switch change {
        case let .inserted(message, conversationID):
            guard conversationID == selectedConversationID,
                  message.role != .tool else { return }
            if message.role == .user { latestUserMessageID = message.id }
            var next = persistedMessages
            if let index = next.firstIndex(where: { $0.id == message.id }) {
                next[index] = message
            } else {
                next.append(message)
                next.sort(by: messageOrdering)
            }
            // Important: 这里**不**按 `maxRetainedCount` 裁剪窗口头部。
            //
            // 裁掉的是**最旧**的消息 —— 用户可能刚翻到那里看历史，新消息一到
            // 它们就从窗口里消失了。窗口长度由另外两条路径守住：
            // 尾部刷新与向上翻页时的窗口回收。
            persistedMessages = next
        case let .cleared(conversationID: conversationID):
            guard conversationID == selectedConversationID else { return }
            // Important: 清空必须**直接清掉窗口**，不能走尾部刷新。
            //
            //   尾部刷新在存储层已空时取不到最近一页，会提前返回而不动窗口 ——
            //   于是被清空的消息继续留在界面上。方案 Task 5 明确要求
            //   「清空不残留旧行」，因此这里直接清空窗口。
            persistedMessages = []
            hasEarlierMessages = false
            latestUserMessageID = nil
            streamingRow = nil
            activityMessage = services.activityMessage(for: conversationID)
            projectionStore.reset()
        case let .persisted(_, conversationID),
             let .updated(conversationID: conversationID),
             let .deleted(_, conversationID: conversationID):
            guard conversationID == selectedConversationID else { return }
            Task { @MainActor [weak self] in await self?.refreshTail() }
        }
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

    /// 从流式服务读取当前状态，更新 `streamingRow`。
    private func applyStreamingState() {
        guard streamingDisplayEnabled else {
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

    /// 只从落库消息重建稳定历史行。
    ///
    /// - Important: 历史行的重建由**内容哈希**把关：
    ///   等长替换（"AAAA" → "BBBB"）也会触发重建，
    ///   否则历史行会继续持有旧文本。
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
                    contentHash: $0.content.hashValue,
                    role: $0.role,
                    isToolExecutionOnly: $0.isToolExecutionOnly,
                    toolCallResultState: $0.toolCalls?.map {
                        let result = $0.result
                        let resultState = result.map {
                            "\($0.content.count):\($0.awaitingUserResponse == true)"
                        } ?? "nil"
                        return "\($0.id):\(resultState)"
                    } ?? [],
                    toolCallAuthorizationState: $0.toolCalls?.map {
                        "\($0.id):\($0.authorizationState ?? "nil")"
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
