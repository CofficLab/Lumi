import Combine
import Foundation
import ProviderMessage
import ProviderLLM

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

/// LLM / tool orchestration is injected through this responder boundary.
/// The loop itself owns lifecycle and message persistence, not provider protocol details.
public typealias AgentLoopResponder = @MainActor @Sendable (AgentLoopRequest) async throws -> String

@MainActor
public protocol AgentLoopProviding: AnyObject, ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 执行一轮回合（主入口：用户发送消息后驱动）。
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome
    /// 恢复被挂起的回合。
    func resumeTurn(in conversationID: UUID) async throws -> AgentLoopOutcome
    /// 显式开始一个回合并返回句柄（由原 `AgentTurnProviding.createTurn` 合并而来）。
    func createTurn(_ request: AgentTurnRequest) async throws -> AgentTurnHandle
    func cancelTurn(in conversationID: UUID)
    func state(for conversationID: UUID) -> AgentLoopState
    func isRunning(for conversationID: UUID) -> Bool
    func setResponder(_ responder: AgentLoopResponder?)
    func setLLMProvider(_ provider: (any LLMProviding)?)
}
