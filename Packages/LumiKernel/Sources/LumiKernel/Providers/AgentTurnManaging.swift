import Foundation

/// The lifecycle state of an agent turn managed by the kernel.
public enum AgentTurnState: Sendable, Equatable {
    case idle
    case running
    case suspended(AgentTurnSuspension)
    case completed
    case failed
    case cancelled
}

/// Persistable information describing why a turn is waiting and how it can resume.
public struct AgentTurnSuspension: Codable, Sendable, Equatable {
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

/// The user/plugin-provided value used to resume a suspended turn.
public struct AgentTurnResumeRequest: Sendable, Equatable {
    public let suspensionID: String
    public let answer: String

    public init(suspensionID: String, answer: String) {
        self.suspensionID = suspensionID
        self.answer = answer
    }
}

/// Work owned by a parent turn that may complete after the parent has
/// suspended. The manager starts this work only after the parent suspension has
/// been persisted, then resumes the parent with the returned answer.
public typealias AgentTurnChildWork = @MainActor @Sendable () async -> String

/// Control signal returned alongside a tool result.
public enum AgentTurnControl: Codable, Sendable, Equatable {
    case continueTurn
    case suspend(AgentTurnSuspension)
    case resumed(AgentTurnSuspension, answer: String)

    public var isSuspended: Bool {
        if case .suspend = self { return true }
        return false
    }

    public var isUserInteraction: Bool {
        switch self {
        case .suspend, .resumed:
            return true
        case .continueTurn:
            return false
        }
    }

    public var answer: String? {
        guard case let .resumed(_, answer) = self else { return nil }
        return answer
    }
}

public enum AgentTurnManagingError: Error, LocalizedError, Sendable {
    case resumeNotSupported
    case invalidResumeRequest
    case turnFailed

    public var errorDescription: String? {
        switch self {
        case .resumeNotSupported:
            "This agent turn manager does not support resuming suspended turns yet."
        case .invalidResumeRequest:
            "The agent turn is not suspended or the resume request does not match it."
        case .turnFailed:
            "The agent turn failed while executing."
        }
    }
}

/// Manages agent-turn execution and lifecycle.
@MainActor
public protocol AgentTurnManaging: AnyObject {
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
}

public extension AgentTurnManaging {
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
