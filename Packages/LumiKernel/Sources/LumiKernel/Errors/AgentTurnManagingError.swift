import Foundation

/// Errors surfaced by an ``AgentTurnManaging`` implementation.
///
/// Lives in the `Errors/` directory per project convention (alongside
/// ``LumiKernelError``); companion domain types such as ``AgentTurnState``,
/// ``AgentTurnSuspension`` and ``AgentTurnControl`` remain in
/// `Types/Conversation/AgentTurnTypes.swift`.
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
