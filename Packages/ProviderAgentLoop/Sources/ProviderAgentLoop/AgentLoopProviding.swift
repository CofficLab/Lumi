import Foundation
import ProviderConversation
import KitLLM
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import ProviderLifecycleHooks

public enum AgentLoopState: String, Codable, Sendable {
    case idle
    case running
    case suspended
    case completed
    case failed
    case cancelled
}

public enum AgentLoopOutcome: Sendable, Equatable {
    case completed
    case failed(String)
    case cancelled
    case suspended(String)
}

public struct AgentLoopRequest: Sendable {
    public let conversationID: UUID
    public let messages: [Message]

    public init(conversationID: UUID, messages: [Message]) {
        self.conversationID = conversationID
        self.messages = messages
    }
}

/// 一次工具/交互导致的回合暂停点。
///
/// 对齐旧版 `AgentTurnSuspension`：`kind` 区分暂停原因（`toolApproval` /
/// `askUser` 等），`payload` 是 JSON 字符串（选项、问题等）。用户回答后经
/// `resumeTurn(in:request:)` 恢复。
public struct AgentLoopSuspension: Sendable, Equatable {
    public let suspensionID: String
    public let conversationID: UUID
    public let toolCallID: String?
    public let kind: String
    public let payload: String

    public init(
        suspensionID: String,
        conversationID: UUID,
        toolCallID: String? = nil,
        kind: String,
        payload: String
    ) {
        self.suspensionID = suspensionID
        self.conversationID = conversationID
        self.toolCallID = toolCallID
        self.kind = kind
        self.payload = payload
    }
}

/// 恢复一次暂停回合的请求。
public struct AgentTurnResumeRequest: Sendable, Equatable {
    public let suspensionID: String
    public let answer: String

    public init(suspensionID: String, answer: String) {
        self.suspensionID = suspensionID
        self.answer = answer
    }
}

/// LLM / tool orchestration is injected through this responder boundary.
/// The loop itself owns lifecycle and message persistence, not provider protocol details.
public typealias AgentLoopResponder = @MainActor @Sendable (AgentLoopRequest) async throws -> String

/// Agent 回合管理（KernelCore 体系）。
///
/// 复刻旧版 `AgentTurnRunner` 的职责：防并发 runTurn、流式 LLM 调用、
/// 工具执行与授权暂停/恢复、错误落库、取消。依赖通过 set 注入：
/// - `MessageManaging`（构造注入，消息历史与落库）
/// - `LLMProviding` / `LLMStreamingProviding`（setLLMProvider）
/// - `ToolManagerProviding`（setToolManager）
/// - `MessageStreamingProviding`（setStreaming）
/// - `ConversationManaging`（setConversations，读取 automationLevel 等会话设置）
@MainActor
public protocol AgentLoopProviding: AnyObject, ObservableObject {
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome
    func cancelTurn(in conversationID: UUID)
    func state(for conversationID: UUID) -> AgentLoopState
    /// 当前（或最近一次）暂停的详情；无暂停时返回 `nil`。
    func suspension(for conversationID: UUID) -> AgentLoopSuspension?
    func isRunning(for conversationID: UUID) -> Bool
    func currentTurnID(for conversationID: UUID) -> UUID?

    func setResponder(_ responder: AgentLoopResponder?)
    func setLLMProvider(_ provider: (any LLMProviding)?)
    func setToolManager(_ toolManager: (any ToolManagerProviding)?)
    func setStreaming(_ streaming: (any MessageStreamingProviding)?)
    func setConversations(_ conversations: (any ConversationManaging)?)

    /// 注入回合生命周期事件回调（宿主桥接到事件总线 / 通知中心）。
    func setEventHandler(_ handler: AgentLoopEventHandler?)

    /// 注入生命周期钩子管理器，回合循环在各关键节点触发对应钩子。
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?)
}

public extension AgentLoopProviding {
    func setEventHandler(_ handler: AgentLoopEventHandler?) {}

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

    /// 兼容重载：无 request 的恢复（合并自旧版 `AgentTurnManaging.resumeTurn(in:)`），
    /// 视为对新回合直接执行。
    func resumeTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        try await runTurn(in: conversationID)
    }
}
