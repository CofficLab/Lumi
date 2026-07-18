import Foundation
import LumiCoreMessage

/// Context provided to each `LumiAgentTurnCheck` during evaluation.
public struct TurnContext: Sendable {
    /// Which conversation this turn belongs to.
    public let conversationID: UUID

    /// Zero-based iteration index within the current agent turn.
    public let iteration: Int

    /// The assistant message just produced by the LLM.
    public let assistantMessage: LumiChatMessage

    /// All messages in the conversation so far (including the assistant message).
    public let messages: [LumiChatMessage]

    public init(
        conversationID: UUID,
        iteration: Int,
        assistantMessage: LumiChatMessage,
        messages: [LumiChatMessage]
    ) {
        self.conversationID = conversationID
        self.iteration = iteration
        self.assistantMessage = assistantMessage
        self.messages = messages
    }
}

/// A pluggable check that runs after each LLM response in the agent loop.
///
/// Return `nil` to allow the loop to continue.
/// Return a non-nil string to **terminate** the loop — the string is used as the error message.
///
/// Checks are evaluated in registration order; the first non-nil result stops the loop.
public protocol LumiAgentTurnCheck: Sendable {
    func evaluate(_ context: TurnContext) async -> String?
}