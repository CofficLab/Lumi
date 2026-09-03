import KitAgentTool
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import KitSuperLog

/// Agent 回合执行器门面。
///
/// 内部使用有限状态机（`TurnRuntime` + `TurnReducer`）管理回合生命周期，
/// 替代原先散落在 8 个字典/集合中的状态 + while 循环控制流。
@MainActor
public final class AgentLoopManager: AgentLoopProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-loop")
    public nonisolated static let emoji = "🔄"
    public static let verbose = false
    public static let printMessages = false

    // MARK: - Dependencies

    let messages: any MessageManaging
    let llmManager: any LLMManaging
    let toolManager: any ToolManagerProviding
    let streaming: any MessageStreamingProviding
    let conversations: any ConversationManaging
    let contextProvider: any LLMContextProviding
    var lifecycleHooks: (any LifecycleHooksProviding)?

    // MARK: - FSM State (single source of truth)

    /// 每会话的回合运行时上下文。替代原先 8 个散落的字典/集合。
    var runtimes: [UUID: TurnRuntime] = [:]
    var resumingConversations: Set<UUID> = []
    struct CompletionWaiter {
        let turnID: UUID
        let continuation: CheckedContinuation<AgentLoopOutcome, Never>
    }

    var completionWaiters: [UUID: [CompletionWaiter]] = [:]
    private var agentLoopObservers: [UUID: (AgentLoopEvent) -> Void] = [:]

    // MARK: - Init

    init(
        messages: any MessageManaging,
        llmManager: any LLMManaging,
        toolManager: any ToolManagerProviding,
        streaming: any MessageStreamingProviding,
        conversations: any ConversationManaging,
        contextProvider: any LLMContextProviding
    ) {
        self.messages = messages
        self.llmManager = llmManager
        self.toolManager = toolManager
        self.streaming = streaming
        self.conversations = conversations
        self.contextProvider = contextProvider
    }

    public func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        let id = UUID()
        agentLoopObservers[id] = callback
        return PluginAgentLoopObserverHandle { [weak self] in
            self?.agentLoopObservers.removeValue(forKey: id)
        }
    }

    func notify(_ event: AgentLoopEvent) {
        for callback in agentLoopObservers.values {
            callback(event)
        }
    }

    // MARK: - AgentLoopProviding

    public func state(for conversationID: UUID) -> AgentLoopState {
        let runtime = runtimes[conversationID]
        let phase = runtime?.phase ?? .idle
        let state: AgentLoopState
        switch phase {
        case .idle: state = .idle
        case .requestingLLM, .executingTools, .waitingForToolJobs: state = .running
        case .awaitingUser: state = .suspended
        case .completed: state = .completed
        case .failed: state = .failed
        case .cancelled: state = .cancelled
        }
        if Self.verbose && state != .idle {
            Self.logger.debug("\(Self.t)查询状态 - conversationID: \(conversationID), phase: \(String(describing: phase)), state: \(state.rawValue)")
        }
        return state
    }

    public func suspension(for conversationID: UUID) -> AgentLoopSuspension? {
        runtimes[conversationID]?.activeSuspension
    }

    public func currentTurnID(for conversationID: UUID) -> UUID? {
        runtimes[conversationID]?.turnID
    }

    public func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {
        lifecycleHooks = hooks
    }

    func notifyTurnFinished(
        conversationID: UUID,
        turnID: UUID,
        outcome: AgentLoopOutcome
    ) async {
        let reason: TurnEndReason
        switch outcome {
        case .completed: reason = .completed
        case .failed: reason = .failed
        case .cancelled: reason = .cancelled
        case .suspended: reason = .suspended
        }
        await lifecycleHooks?.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turnID,
                endReason: reason
            )
        )
    }

    // MARK: - Internal Helpers

    func languagePreference(for conversationID: UUID) -> LanguagePreference {
        let language = conversations.language(for: conversationID)
        switch language {
        case .chinese: return .chinese
        case .english: return .english
        }
    }

    func resolvedProviderID(for conversationID: UUID) -> String? {
        conversations.providerID(for: conversationID)
    }

    /// Provider 可能不响应 Swift Task 的取消；所有会产生消息或推进状态的
    /// LLM 结果都必须再次确认仍属于当前未取消的 requestingLLM 回合。
    func isActiveLLMRequest(conversationID: UUID, turnID: UUID) -> Bool {
        guard let runtime = runtimes[conversationID] else { return false }
        return runtime.lastTurnID == turnID
            && runtime.phase == .requestingLLM(turnID: turnID)
            && !runtime.cancelRequested
            && !Task.isCancelled
    }
}

// MARK: - Streaming Bridge

/// 把 MainActor 隔离的流式 store 桥接为 `@Sendable` 可捕获值。
final class StreamingBridge: @unchecked Sendable {
    private let streaming: any MessageStreamingProviding

    init(streaming: any MessageStreamingProviding) {
        self.streaming = streaming
    }

    @MainActor
    func appendContent(_ content: String, conversationID: UUID) {
        streaming.appendContent(content, conversationID: conversationID)
    }

    @MainActor
    func appendThinking(_ content: String, conversationID: UUID) {
        streaming.appendThinking(content, conversationID: conversationID)
    }
}
