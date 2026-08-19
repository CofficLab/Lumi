import AgentToolKit
import Foundation
import KitLLM
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import SuperLogKit

/// Agent 回合执行器门面。
@MainActor
public final class AgentLoopProvider: AgentLoopProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-loop")
    public nonisolated static let emoji = "🔄"
    public static let verbose = true

    // MARK: - Dependencies

    let messages: any MessageManaging
    let llmManager: any LLMManaging
    let toolManager: any ToolManagerProviding
    let streaming: any MessageStreamingProviding
    let conversations: any ConversationManaging

    // MARK: - Turn State

    var states: [UUID: AgentLoopState] = [:]
    var tasks: [UUID: Task<AgentLoopOutcome, Never>] = [:]
    var suspensions: [UUID: AgentLoopSuspension] = [:]
    /// 当前 assistant 工具批次中所有挂起的调用（一个批次可含多个 ask_user）。
    var pendingSuspensions: [UUID: [String: AgentLoopSuspension]] = [:]
    var turnIDs: [UUID: UUID] = [:]
    var cancelledConversations: Set<UUID> = []
    var awaitingConversations: Set<UUID> = []
    var failedConversations: Set<UUID> = []

    static let toolApprovalSuspensionKind = "toolApproval"

    // MARK: - Init

    init(
        messages: any MessageManaging,
        llmManager: any LLMManaging,
        toolManager: any ToolManagerProviding,
        streaming: any MessageStreamingProviding,
        conversations: any ConversationManaging
    ) {
        self.messages = messages
        self.llmManager = llmManager
        self.toolManager = toolManager
        self.streaming = streaming
        self.conversations = conversations
    }

    // MARK: - AgentLoopProviding

    public func state(for conversationID: UUID) -> AgentLoopState {
        let state = states[conversationID] ?? .idle
        if Self.verbose && state != .idle {
            Self.logger.debug("\(Self.t)查询状态 - conversationID: \(conversationID), state: \(state.rawValue)")
        }
        return state
    }

    public func suspension(for conversationID: UUID) -> AgentLoopSuspension? {
        suspensions[conversationID]
    }

    public func currentTurnID(for conversationID: UUID) -> UUID? {
        turnIDs[conversationID]
    }

    public func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

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
}

// MARK: - Streaming Bridge

/// 把 MainActor 隔离的流式 store 桥接为 `@Sendable` 可捕获值。
///
/// `MessageStreamingProviding` 是 MainActor 隔离的存在类型，不能直接捕获进
/// `LLMStreamingProviding.streamComplete` 的 `@Sendable` 回调；本包装类标记
/// `@unchecked Sendable`，回调内经 `await` 跳回 MainActor 写入，保证对
/// `@Published` 的写安全。
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
