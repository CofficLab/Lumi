import Foundation

/// Outcome of a completed agent turn.
public enum AgentTurnOutcome: Sendable {
    /// Turn completed normally with no tool calls or after all tool calls were executed.
    case completed

    /// Turn ended due to an error (LLM failure, tool execution error, etc.).
    case failed(Error)

    /// Turn ended because user rejected a tool call.
    case userRejection

    /// Turn ended because it's waiting for user input (e.g., ask_user tool).
    case awaitingUserResponse

    /// Turn was cancelled by user or system.
    case cancelled

    /// The reason if the turn ended unsuccessfully.
    public var turnEndReason: LumiTurnEndReason {
        switch self {
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .userRejection:
            return .userRejection
        case .awaitingUserResponse:
            return .awaitingUserResponse
        case .cancelled:
            return .cancelled
        }
    }

    /// Whether automatic continuation is allowed after this outcome.
    public var allowsAutomaticContinuation: Bool {
        turnEndReason.allowsAutomaticContinuation
    }
}
