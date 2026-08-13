import Foundation

public struct LumiPendingToolConfirmation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let toolCall: LumiToolCall
    public let displayDescription: String

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        toolCall: LumiToolCall,
        displayDescription: String
    ) {
        self.id = id
        self.conversationID = conversationID
        self.toolCall = toolCall
        self.displayDescription = displayDescription
    }
}
