import Foundation
import LumiLoggingKit
import os
import ProviderAgentLoop
import ProviderConversationState

/// 由插件持有的会话状态实现。
///
/// Provider 只负责保存、读取和更新状态；事件来源及其转换逻辑由
/// `Observers` 目录中的独立观察者负责。
///
/// # 结构性地保证 `activity` 的终态不变量
///
/// `activity` 表达「这个会话**此刻**在做什么」。因此有一条必须成立的不变量：
///
/// > **回合处于终态时，不存在「正在做的事」，`activity` 必须为 nil。**
///
/// 这条不变量在本 Provider 层被强制，而不是靠每个观察者各自记得清理。
/// 靠观察者清理必然漏——它们只能看到自己那几种事件，看不到彼此的时序。
/// 典型故障（2026-10-21 15:50:02）：回合被取消后，一条迟到的 ToolManager
/// 事件把 activity 写回 `.waitingForUser`，界面于是永远显示「等待你的输入…」，
/// 而此时已无任何卡片可供回答。
@MainActor
public final class ConversationStateProvider: ConversationStateProviding, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-state",
        category: "Provider"
    )
    nonisolated public static let emoji = "📋"
    nonisolated public static let verbose = false

    public private(set) var states: [UUID: ConversationStateSnapshot] = [:]
    private var observers: [UUID: Observer] = [:]

    public init() {
        if Self.verbose {
            Self.logger.debug("\(Self.t)initialized")
        }
    }

    @discardableResult
    public func addConversationStateObserver(
        _ callback: @escaping (ConversationStateEvent) -> Void
    ) -> any ConversationStateObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers[observer.id] = observer
        return observer
    }

    public func state(for conversationID: UUID) -> ConversationStateSnapshot {
        states[conversationID] ?? ConversationStateSnapshot(conversationID: conversationID)
    }

    /// 合并指定会话的状态变化，并发布结构化状态事件。
    public func update(
        conversationID: UUID,
        turnID: UUID? = nil,
        agentLoopState: AgentLoopState? = nil,
        toolState: ConversationToolState? = nil,
        authorizationState: ConversationAuthorizationState? = nil,
        activity: ConversationActivity? = nil,
        jobActivity: ConversationJobActivity? = nil,
        clearActivity: Bool = false,
        lastError: String? = nil,
        clearError: Bool = false
    ) {
        let current = state(for: conversationID)
        let resolvedLoopState = agentLoopState ?? current.agentLoopState
        update(
            ConversationStateSnapshot(
                conversationID: conversationID,
                turnID: turnID ?? current.turnID,
                agentLoopState: resolvedLoopState,
                toolState: toolState ?? current.toolState,
                authorizationState: authorizationState ?? current.authorizationState,
                activity: resolvedActivity(
                    clearActivity: clearActivity,
                    incoming: activity,
                    current: current.activity,
                    agentLoopState: resolvedLoopState
                ),
                jobActivity: jobActivity ?? current.jobActivity,
                lastError: clearError ? nil : (lastError ?? current.lastError)
            )
        )
    }

    /// 替换指定会话的完整状态快照。
    public func update(_ snapshot: ConversationStateSnapshot) {
        let sanitized = ConversationStateSnapshot(
            conversationID: snapshot.conversationID,
            turnID: snapshot.turnID,
            agentLoopState: snapshot.agentLoopState,
            toolState: snapshot.toolState,
            authorizationState: snapshot.authorizationState,
            activity: Self.sanitizedActivity(
                snapshot.activity,
                agentLoopState: snapshot.agentLoopState
            ),
            jobActivity: snapshot.jobActivity,
            lastError: snapshot.lastError
        )
        states[sanitized.conversationID] = sanitized
        notify(.updated(sanitized.conversationID))
        if Self.verbose {
            let turn = sanitized.turnID?.uuidString ?? "nil"
            let error = sanitized.lastError ?? "nil"
            let stateDescription = [
                "conversation=\(sanitized.conversationID.uuidString)",
                "turn=\(turn)",
                "agentLoop=\(sanitized.agentLoopState.rawValue)",
                "tool=\(sanitized.toolState.rawValue)",
                "authorization=\(sanitized.authorizationState.rawValue)",
                "activity=\(sanitized.activity?.rawValue ?? "none")",
                "jobs=\(sanitized.jobActivity.currentJobCount)/\(sanitized.jobActivity.runningJobCount)",
                "isSending=\(sanitized.isSending)",
                "error=\(error)",
            ].joined(separator: ", ")
            Self.logger.debug("\(Self.t)Conversation state updated: \(stateDescription)")
        }
    }

    /// 回合处于终态时，不存在「正在做的事」，`activity` 必须为空。
    ///
    /// 这是第一性原理给出的结构性保证：观察者只负责**意图**（"这一刻在做什么"），
    /// 而「回合是否还活着」这个前提由 Provider 判定。两者分离后，任何一条
    /// 迟到事件都无法把死掉的回合拖回"正在做事"。
    private static func sanitizedActivity(
        _ activity: ConversationActivity?,
        agentLoopState: AgentLoopState
    ) -> ConversationActivity? {
        guard acceptsActivity(activity, agentLoopState: agentLoopState) else { return nil }
        return activity
    }

    /// 合并「显式清除 / 新值 / 旧值」三种输入，再套用终态约束。
    ///
    /// - Note: 合并发生在**约束之前**。若先套约束再合并，旧快照里残留的
    ///   activity 会在 `clearActivity == false` 时被原样带回，约束就形同虚设。
    private func resolvedActivity(
        clearActivity: Bool,
        incoming: ConversationActivity?,
        current: ConversationActivity?,
        agentLoopState: AgentLoopState
    ) -> ConversationActivity? {
        guard !clearActivity else { return nil }
        return Self.sanitizedActivity(
            incoming ?? current,
            agentLoopState: agentLoopState
        )
    }

    /// 只有仍在进行的回合才承载 activity。
    ///
    /// - Important: `.sending` 是**唯一**在 `agentLoopState == .idle` 时
    ///   也合法的 activity。它由 `MessageSenderStateObserver` 在消息投递阶段
    ///   写入，而回合要到 `AgentLoopEvent.started` 才转成 `.running`——
    ///   两者之间存在一个真实的时间窗口。
    ///
    ///   若把 `.idle` 一律视为终态，这个窗口内的 activity 会被守卫拦掉，
    ///   表现为「发送中」提示闪现或残留（回归见
    ///   `LumiMessageListBriefUITests.testBottomStatusCardIsHiddenWhenIdle`）。
    ///
    ///   因此约束精确到「哪个 activity 可以出现在终态回合上」，
    ///   而不是笼统地按 `agentLoopState` 一刀切。
    private static func acceptsActivity(
        _ activity: ConversationActivity?,
        agentLoopState: AgentLoopState
    ) -> Bool {
        guard let activity else { return false }
        switch agentLoopState {
        case .running, .suspended:
            return true
        case .idle:
            // 发送阶段尚未启动回合，此时只有「正在发送」是真实状态。
            return activity == .sending
        case .completed, .failed, .cancelled:
            return false
        }
    }

    public func remove(conversationID: UUID) {
        guard states.removeValue(forKey: conversationID) != nil else { return }
        notify(.removed(conversationID))
        if Self.verbose {
            Self.logger.debug("\(Self.t)Conversation state removed")
        }
    }

    private func notify(_ event: ConversationStateEvent) {
        observers.values.forEach { $0.invoke(event) }
    }

    private func removeObserver(id: UUID) {
        observers.removeValue(forKey: id)
    }

    private final class Observer: ConversationStateObserverHandle {
        let id = UUID()
        private weak var owner: ConversationStateProvider?
        private let callback: (ConversationStateEvent) -> Void
        private var isCancelled = false

        init(owner: ConversationStateProvider, callback: @escaping (ConversationStateEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            owner?.removeObserver(id: id)
        }

        func invoke(_ event: ConversationStateEvent) {
            guard !isCancelled else { return }
            callback(event)
        }

    }
}