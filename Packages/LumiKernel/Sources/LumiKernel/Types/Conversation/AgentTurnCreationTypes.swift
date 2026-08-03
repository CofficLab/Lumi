import Foundation

/// Request for creating and starting an independent agent turn.
public struct AgentTurnCreationRequest: Sendable, Equatable {
    /// The conversation that requested this turn, if the turn is delegated
    /// from another agent.
    public let parentConversationID: UUID?

    /// Optional conversation title for the created turn.
    public let title: String?

    /// The task/message that starts the created turn.
    public let task: String

    /// Provider/model overrides. `nil` means use the implementation's normal
    /// selection policy.
    public let providerID: String?
    public let modelID: String?

    /// Optional specialist system prompt for the created turn.
    public let systemPrompt: String?

    /// Tool names that must not be exposed to the created turn.
    public let excludedToolNames: Set<String>

    /// The parent turn ID, when the request originates inside an active turn.
    public let parentTurnID: UUID?

    public init(
        parentConversationID: UUID? = nil,
        title: String? = nil,
        task: String,
        providerID: String? = nil,
        modelID: String? = nil,
        systemPrompt: String? = nil,
        excludedToolNames: Set<String> = [],
        parentTurnID: UUID? = nil
    ) {
        self.parentConversationID = parentConversationID
        self.title = title
        self.task = task
        self.providerID = providerID
        self.modelID = modelID
        self.systemPrompt = systemPrompt
        self.excludedToolNames = excludedToolNames
        self.parentTurnID = parentTurnID
    }
}

/// Identifies a turn created by `AgentTurnManaging`.
public struct AgentTurnHandle: Sendable, Equatable {
    public let conversationID: UUID
    public let turnID: UUID

    public init(conversationID: UUID, turnID: UUID) {
        self.conversationID = conversationID
        self.turnID = turnID
    }
}
