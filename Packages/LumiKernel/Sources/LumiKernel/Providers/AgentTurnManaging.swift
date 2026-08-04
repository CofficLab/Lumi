import Foundation

/// Manages agent-turn execution and lifecycle.
@MainActor
public protocol AgentTurnManaging: AnyObject {
    /// Creates and starts an independent agent turn.
    ///
    /// The implementation owns the child conversation/turn lifecycle. This is
    /// the entry point for tools and other Kernel consumers that need to
    /// delegate work to another agent without constructing an agent loop
    /// themselves.
    func createTurn(_ request: AgentTurnCreationRequest) async throws -> AgentTurnHandle

    /// Runs a complete agent turn for the given conversation.
    func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome

    /// Resumes a turn previously returned in the suspended state.
    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentTurnOutcome

    /// Register asynchronous work that belongs to a suspended parent turn.
    ///
    /// Returning `true` means the manager accepted the work and will start it
    /// once the corresponding suspension has been committed. Returning `false`
    /// lets tools fall back to their synchronous behavior when an alternative
    /// manager does not support child work.
    @discardableResult
    func registerChildWork(
        in conversationID: UUID,
        suspensionID: String,
        work: @escaping AgentTurnChildWork
    ) -> Bool

    /// Returns the manager's current state for a conversation.
    func state(for conversationID: UUID) -> AgentTurnState

    /// Cancels the currently running or suspended turn, if any.
    func cancelTurn(in conversationID: UUID)

    /// Compatibility query for callers that only need to know whether work is active.
    func isRunning(for conversationID: UUID) -> Bool

    /// The identifier of the currently active turn, if one exists.
    func currentTurnID(for conversationID: UUID) -> UUID?

    /// Returns the number of currently running turns created by this conversation.
    ///
    /// This is intended for parent-conversation UI, such as a toolbar indicator
    /// showing delegated Agent Turns.
    func activeChildTurnCount(for parentConversationID: UUID) -> Int
}

public extension AgentTurnManaging {
    func createTurn(_ request: AgentTurnCreationRequest) async throws -> AgentTurnHandle {
        throw AgentTurnManagingError.createNotSupported
    }

    func currentTurnID(for conversationID: UUID) -> UUID? { nil }

    func activeChildTurnCount(for parentConversationID: UUID) -> Int { 0 }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentTurnOutcome {
        throw AgentTurnManagingError.resumeNotSupported
    }

    func state(for conversationID: UUID) -> AgentTurnState {
        isRunning(for: conversationID) ? .running : .idle
    }

    @discardableResult
    func registerChildWork(
        in conversationID: UUID,
        suspensionID: String,
        work: @escaping AgentTurnChildWork
    ) -> Bool {
        false
    }
}
