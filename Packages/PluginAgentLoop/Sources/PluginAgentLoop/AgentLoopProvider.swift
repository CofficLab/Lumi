import AgentToolKit
import Foundation
import Combine
import os
import ProviderAgentLoop
import ProviderMessage
import ProviderLLMVendors
import ProviderToolManager
import ProviderMessageStreaming
import ProviderConversation
import SuperLogKit

/// Agent 回合执行器。
///
/// 回合循环：
/// 1. 把消息历史（含 tool 结果）发送给 LLM；
/// 2. 流式接收增量（text / thinking）写入 `MessageStreamingProviding`；
/// 3. 收到带工具调用的响应后逐个执行（按会话 automationLevel 评估授权，
///    高风险调用挂起等待用户批准/拒绝）；
/// 4. 工具结果以 `.tool` 消息落库，带回 LLM 继续下一轮；
/// 5. 直到 LLM 输出无工具调用的最终响应，回合完成。
///
/// 对齐 `AgentLoopProviding` 语义：
/// - 会话级供应商/模型选择（`ConversationManaging` 为事实来源，全局选中兜底）；
/// - 流式优先（`LLMStreamingProviding`），未实现流式时回退 `complete(_:)`；
/// - `MessageStreamingProviding` 临时行 + 最终落库行分离，落库后清理临时行；
/// - 瞬时 status 消息（正在思考…/正在执行…）由 `MessageManaging` 仅存内存；
/// - 回合生命周期经 `AgentLoopEventHandler` 广播（宿主桥接事件总线/通知）。
///
/// 说明：回合循环（runTurn / resumeTurn / executeTurnLoop 及配套工具执行、
/// 批次续跑、辅助方法）提取在 `AgentLoopProvider+Loop.swift` 扩展中；本文件
/// 仅承载类型声明、存储属性、依赖注入与轻量状态访问器。因跨文件扩展无法访问
/// `private` 成员，存储属性开放为 `internal`（模块内可见）。
@MainActor
public final class AgentLoopProvider: AgentLoopProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-loop")
    public nonisolated static let emoji = "🔄"
    public static let verbose = true

    let messages: any MessageManaging
    var responder: AgentLoopResponder?
    var llmProvider: (any LLMProviding)?
    var toolManager: (any ToolManagerProviding)?
    var streaming: (any MessageStreamingProviding)?
    var conversations: (any ConversationManaging)?
    var eventHandler: AgentLoopEventHandler?
    /// LLM 请求前的消息准备钩子，按注册顺序执行。
    var messagePreparers: [AgentLoopMessagePreparer] = []

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

    @Published public internal(set) var revision: Int = 0

    public init(messages: any MessageManaging) {
        self.messages = messages
    }

    // MARK: - Injection

    public func setResponder(_ responder: AgentLoopResponder?) {
        self.responder = responder
    }

    public func setLLMProvider(_ provider: (any LLMProviding)?) {
        llmProvider = provider
    }

    public func setToolManager(_ toolManager: (any ToolManagerProviding)?) {
        self.toolManager = toolManager
    }

    public func setStreaming(_ streaming: (any MessageStreamingProviding)?) {
        self.streaming = streaming
    }

    public func setConversations(_ conversations: (any ConversationManaging)?) {
        self.conversations = conversations
    }

    public func setEventHandler(_ handler: AgentLoopEventHandler?) {
        eventHandler = handler
    }

    public func addMessagePreparer(_ preparer: @escaping AgentLoopMessagePreparer) {
        messagePreparers.append(preparer)
    }

    // MARK: - AgentLoopProviding

    public func state(for conversationID: UUID) -> AgentLoopState {
        let state = states[conversationID] ?? .idle
        if Self.verbose && state != .idle {
            Self.logger.debug("\(Self.t)查询状态 - conversationID: \(conversationID), state: \(state.rawValue)")
        }
        return state
    }

    public func isRunning(for conversationID: UUID) -> Bool {
        tasks[conversationID] != nil || states[conversationID] == .running
    }

    public func suspension(for conversationID: UUID) -> AgentLoopSuspension? {
        suspensions[conversationID]
    }

    public func currentTurnID(for conversationID: UUID) -> UUID? {
        turnIDs[conversationID]
    }

    public func cancelTurn(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)取消回合 - conversationID: \(conversationID)")
        }
        cancelledConversations.insert(conversationID)
        suspensions.removeValue(forKey: conversationID)
        pendingSuspensions.removeValue(forKey: conversationID)
        awaitingConversations.remove(conversationID)
        states[conversationID] = .cancelled
        tasks[conversationID]?.cancel()
        tasks.removeValue(forKey: conversationID)
        revision += 1
    }

    public func createTurn(_ request: AgentTurnRequest) async throws -> AgentTurnHandle {
        states[request.conversationID] = .running
        revision += 1
        return AgentTurnHandle()
    }
}
