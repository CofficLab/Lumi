import Foundation

/// 协调「继续」功能的全部流程。
///
/// ## 职责
///
/// 1. 监听回合生命周期，维护「哪些会话的回合跑到一半被中断了」；
/// 2. 判定当前会话是否该显示「继续」提示；
/// 3. 用户点击「继续」时：修复孤儿 tool_call → 启动新回合。
///
/// ## 中断是怎么被发现的
///
/// 回合开始时写入 `.interrupted` 记录，回合正常结束时改写为终态。
/// 进程崩溃时最后一条记录停留在 `.interrupted` —— 这就是「中断」的信号。
///
/// 这个判定**必须**依赖持久化记录而不是消息形状：用户主动停止与崩溃
/// 在消息层面完全无法区分（见 `ResumableTurnRecord` 的文档）。
@MainActor
final class ResumeCoordinator {
    /// 当前会话的「继续」状态。
    struct State: Equatable {
        /// 是否可继续。
        var isResumable: Bool = false
        /// 提示文案（可继续时才有意义）。
        var reason: String = ""
        /// 当前会话是否正在执行恢复流程。
        ///
        /// - Important: 按会话判定（#888）。它是**当前展示的这条横幅所属
        ///   会话**的恢复状态，不是全局的 —— 会话 A 恢复期间不该禁用会话 B
        ///   的「继续」按钮。
        var isResuming: Bool = false
    }

    // MARK: - Dependencies

    private let loop: any ResumeAgentLoopCapability
    private let messages: any ResumeMessageCapability
    private let conversations: any ResumeConversationCapability
    private let store: ResumableTurnStore
    /// 状态变化回调（驱动 UI 刷新）。
    private let onStateChange: @MainActor (State) -> Void

    // MARK: - Handles

    /// 钩子是否仍然有效。
    ///
    /// 生命周期 Provider 的 `addTurnStartedHook` / `addTurnFinishedHook`
    /// 不返回可取消句柄（只有 `addWillSendToLLMHook` 有），因此用失效标志
    /// 而非注销来停止响应。闭包本身只弱引用协调器，协调器释放后回调
    /// 自然落空，不会造成悬垂访问。
    private var isActive = true
    private var conversationObserver: (any ResumeConversationObserverHandle)?
    private var messageObserver: (any ResumeMessageObserverHandle)?

    // MARK: - State

    /// 当前状态。
    private(set) var state = State()
    /// 正在执行恢复流程的会话，避免重复点击。
    ///
    /// - Important: 必须是**按会话隔离**的集合，而不是单个全局标志（#888）。
    ///   旧实现用单个 `resumingConversationID`，于是会话 A 的恢复回合尚未
    ///   返回时，会话 B 即使有自己独立的中断记录、消息历史和 AgentLoop
    ///   运行时，也无法开始恢复 —— 一次慢速或长期未结束的恢复会无意义地
    ///   串行化其它会话的故障恢复。
    ///
    ///   AgentLoop 侧的 `runtimes` 与 `completionWaiters` 本来就按
    ///   conversationID 隔离，底层支持并行回合，只有这一层退化成了全局单值。
    ///
    ///   集合而非布尔：同一会话的重复恢复仍必须被抑制（否则会并发启动
    ///   两个回合），但不同会话之间互不阻塞。
    private var resumingConversationIDs: Set<UUID> = []

    init(
        loop: any ResumeAgentLoopCapability,
        messages: any ResumeMessageCapability,
        conversations: any ResumeConversationCapability,
        store: ResumableTurnStore,
        onStateChange: @escaping @MainActor (State) -> Void
    ) {
        self.loop = loop
        self.messages = messages
        self.conversations = conversations
        self.store = store
        self.onStateChange = onStateChange
    }

    // MARK: - 生命周期

    /// 启动监听。
    func start(hooks: any ResumeLifecycleHooksCapability) {
        isActive = true

        // 钩子会被 `await`，因此直接 await 即可。
        //
        // 刻意**不**包 `Task {}`：回合开始的记录必须同步落盘，否则崩溃可能
        // 发生在 Task 被调度之前，记录丢失，崩溃检测彻底失效。
        // `AgentLoopManager.runTurn` 会 await `notifyTurnStarted`，因此这里的
        // 写入发生在 LLM 请求发出之前 —— 请求期间的崩溃也能被检出。
        hooks.onTurnStarted { [weak self] event in
            await self?.handleTurnStarted(event)
        }

        hooks.onTurnFinished { [weak self] event in
            await self?.handleTurnFinished(event)
        }

        // 观察者回调不是 async，只能用 Task 承接。
        // 这里允许异步：状态刷新是 UI 层面的事，晚一拍不影响正确性。
        conversationObserver = conversations.addObserver { [weak self] conversationID in
            Task { @MainActor [weak self] in
                await self?.refreshState(for: conversationID)
            }
        }

        messageObserver = messages.addObserver { [weak self] conversationID in
            Task { @MainActor [weak self] in
                await self?.refreshState(for: conversationID)
            }
        }
    }

    /// 停止监听。
    func cancel() {
        isActive = false
        conversationObserver?.cancel()
        conversationObserver = nil
        messageObserver?.cancel()
        messageObserver = nil
    }

    // MARK: - 回合事件

    private func handleTurnStarted(_ event: ResumeTurnEvent) async {
        guard isActive else { return }
        await store.markRunning(
            conversationID: event.conversationID,
            turnID: event.turnID
        )
        await refreshState(for: event.conversationID)
    }

    private func handleTurnFinished(_ event: ResumeTurnEvent) async {
        guard isActive else { return }
        let outcome: ResumableTurnRecord.Outcome
        switch event.endReason {
        case .completed: outcome = .completed
        case .failed: outcome = .failed
        case .cancelled: outcome = .cancelled
        case .suspended: outcome = .suspended
        case nil: outcome = .failed
        }

        await store.markFinished(
            conversationID: event.conversationID,
            turnID: event.turnID,
            outcome: outcome
        )
        await refreshState(for: event.conversationID)
    }

    // MARK: - 状态判定

    /// 重新计算某会话的「继续」状态。
    func refreshState(for conversationID: UUID?) async {
        guard isActive else { return }
        guard let conversationID else {
            apply(State())
            return
        }
        // 只有当前选中的会话才影响 UI。
        guard conversations.selectedConversationID == conversationID else { return }

        let record = await store.record(for: conversationID)
        let history = await messages.messages(for: conversationID)
        let turnState = loop.turnState(for: conversationID)

        let verdict = ResumeEligibility.evaluate(
            ResumeEligibility.Input(
                turnRecord: record,
                agentLoopState: turnState,
                messages: history
            )
        )

        switch verdict {
        case let .resumable(reason):
            apply(State(isResumable: true, reason: reason, isResuming: isResuming(conversationID)))
        case .notResumable:
            apply(State(isResuming: isResuming(conversationID)))
        }
    }

    private func apply(_ newState: State) {
        guard newState != state else { return }
        state = newState
        onStateChange(newState)
    }

    // MARK: - 恢复

    /// 执行「继续」。
    ///
    /// 流程：
    /// 1. 复查当前状态（点击可能发生在状态已变化之后）；
    /// 2. 修复孤儿 tool_call —— 否则这次 LLM 请求必然被 provider 拒绝；
    /// 3. 启动新回合。
    ///
    /// - Parameter conversationID: 要恢复的会话。默认取当前选中的会话。
    ///
    /// - Important: 恢复的互斥必须**按会话**判定（#888）。旧实现在这里用
    ///   全局 `resumingConversationID == nil` 做 guard，于是任何其它会话正在
    ///   恢复时，本会话的恢复会被静默拒绝。改为集合后：同一会话的重复恢复
    ///   仍被抑制，不同会话之间互不阻塞。
    func resume(for requestedConversationID: UUID? = nil) async {
        guard isActive else { return }
        let conversationID = requestedConversationID ?? conversations.selectedConversationID
        guard let conversationID else { return }
        // 同一会话的重复恢复要挡住；别的会话正在恢复与此无关。
        guard resumingConversationIDs.insert(conversationID).inserted else { return }
        defer { resumingConversationIDs.remove(conversationID) }

        // 恢复状态变化要立刻反映到「继续」按钮上（#888）。
        publishResumeState(for: conversationID)

        await refreshState(for: conversationID)
        guard state.isResumable else {
            publishResumeState(for: conversationID)
            return
        }

        await repairOrphanToolCalls(in: conversationID)

        // 修复后历史已经变了，重新判定一次：修复会写入 tool 消息，
        // 可能让「已产出最终回复」的判断发生变化。
        await refreshState(for: conversationID)

        await loop.startTurn(for: conversationID)
        await refreshState(for: conversationID)
        publishResumeState(for: conversationID)
    }

    /// 某会话当前是否正在执行恢复流程。
    ///
    /// 供 UI 判断「继续」按钮是否该禁用。必须按会话判定：一个会话的恢复
    /// 不该禁用另一个会话的按钮（#888）。
    func isResuming(_ conversationID: UUID) -> Bool {
        resumingConversationIDs.contains(conversationID)
    }

    /// 把某个会话的恢复状态变化推给 UI。
    ///
    /// 只在会话当前被选中时才影响展示 —— `refreshState` 也遵守这条规则。
    private func publishResumeState(for conversationID: UUID) {
        guard isActive else { return }
        guard conversations.selectedConversationID == conversationID else { return }
        var newState = state
        newState.isResuming = isResuming(conversationID)
        apply(newState)
    }

    /// 为未配对的 tool_call 补写占位 tool result。
    private func repairOrphanToolCalls(in conversationID: UUID) async {
        let history = await messages.messages(for: conversationID)
        let orphans = OrphanToolCallScanner.scan(history)
        guard !orphans.isEmpty else { return }

        for placeholder in OrphanToolCallRepair.placeholderMessages(
            for: orphans,
            conversationID: conversationID
        ) {
            messages.insertMessage(placeholder, to: conversationID)
        }
    }
}
