import Foundation

public enum AgentTurnState: String, Sendable { case idle, running, suspended, completed, failed, cancelled }
public enum AgentTurnOutcome: Sendable, Equatable { case completed, failed(String), cancelled, suspended(String) }
public struct AgentTurnRequest: Sendable {
    public let conversationID: UUID
    public let prompt: String
    public init(conversationID: UUID, prompt: String) { self.conversationID = conversationID; self.prompt = prompt }
}
public struct AgentTurnHandle: Sendable, Equatable { public let id: UUID; public init(id: UUID = UUID()) { self.id = id } }
public typealias AgentTurnChildWork = @MainActor @Sendable () async -> Void

@MainActor
public protocol AgentTurnProviding: AnyObject {
    func createTurn(_ request: AgentTurnRequest) async throws -> AgentTurnHandle
    func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome
    func resumeTurn(in conversationID: UUID) async throws -> AgentTurnOutcome
    func state(for conversationID: UUID) -> AgentTurnState
    func cancelTurn(in conversationID: UUID)
    func isRunning(for conversationID: UUID) -> Bool
}

@MainActor
public final class DefaultAgentTurnProviding: AgentTurnProviding {
    private var states: [UUID: AgentTurnState] = [:]
    public init() {}
    public func createTurn(_ request: AgentTurnRequest) async throws -> AgentTurnHandle { states[request.conversationID] = .running; return AgentTurnHandle() }
    public func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome { states[conversationID] = .completed; return .completed }
    public func resumeTurn(in conversationID: UUID) async throws -> AgentTurnOutcome { states[conversationID] = .completed; return .completed }
    public func state(for conversationID: UUID) -> AgentTurnState { states[conversationID] ?? .idle }
    public func cancelTurn(in conversationID: UUID) { states[conversationID] = .cancelled }
    public func isRunning(for conversationID: UUID) -> Bool { state(for: conversationID) == .running }
}
