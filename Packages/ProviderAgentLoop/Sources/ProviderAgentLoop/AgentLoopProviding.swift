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

/// 一次工具/交互导致的回合暂停点。
///
/// `kind` 区分暂停原因（`toolApproval` / `askUser` 等），`payload` 是 JSON
/// 字符串（选项、问题等）。用户回答后经 `resumeTurn(in:request:)` 恢复。
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

/// Agent 回合管理。
///
/// 防并发 runTurn、流式 LLM 调用、工具执行与授权暂停/恢复、错误落库、取消。
/// 依赖通过构造注入：
/// - `MessageManaging`（构造注入，消息历史与落库）
/// - `llmManager` / `toolManager` / `streaming` / `conversations`（构造注入）
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

    /// 注入生命周期钩子管理器，回合循环在各关键节点触发对应钩子。
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?)
}
