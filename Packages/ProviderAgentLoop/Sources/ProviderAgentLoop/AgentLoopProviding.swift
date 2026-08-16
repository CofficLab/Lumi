import Foundation
import ProviderMessage
import ProviderLLM

public enum AgentLoopState: String, Codable, Sendable {
    case idle
    case running
    case completed
    case failed
    case cancelled
}

public enum AgentLoopOutcome: Sendable, Equatable {
    case completed
    case failed(String)
    case cancelled
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
public protocol AgentLoopProviding: AnyObject, ObservableObject {
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome
    func cancelTurn(in conversationID: UUID)
    func state(for conversationID: UUID) -> AgentLoopState
    func setResponder(_ responder: AgentLoopResponder?)
    func setLLMProvider(_ provider: (any LLMProviding)?)
}
