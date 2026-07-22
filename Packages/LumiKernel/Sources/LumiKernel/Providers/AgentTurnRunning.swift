import Foundation

/// Manages the execution of a single agent turn.
///
/// An "agent turn" is the cycle of:
/// 1. Sending messages to LLM
/// 2. Receiving response (possibly with tool calls)
/// 3. Executing tool calls and feeding results back to LLM
/// 4. Repeating until the LLM produces a final response (no more tool calls)
///
/// This protocol is typically exposed by a plugin and called by
/// `MessageSendManaging` after a user message is persisted.
@MainActor
public protocol AgentTurnRunning: AnyObject {
    /// Runs a complete agent turn for the given conversation.
    ///
    /// This method blocks until the turn is complete (including all tool executions
    /// and any subsequent LLM calls). If the conversation already has an active turn,
    /// this method should throw or return immediately.
    ///
    /// - Parameter conversationID: The conversation to run the turn in.
    /// - Returns: The outcome of the turn.
    func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome

    /// Cancels the currently running turn for the given conversation, if any.
    ///
    /// If no turn is running for this conversation, this is a no-op.
    /// A cancelled turn should end with `.cancelled` outcome.
    ///
    /// - Parameter conversationID: The conversation whose turn should be cancelled.
    func cancelTurn(in conversationID: UUID)

    /// Returns `true` if a turn is currently running for the given conversation.
    ///
    /// - Parameter conversationID: The conversation to check.
    /// - Returns: `true` if a turn is active, `false` otherwise.
    func isRunning(for conversationID: UUID) -> Bool
}
