import Foundation

public struct LumiSendContext: Sendable {
    public let conversationID: UUID
    public let messages: [LumiChatMessage]

    public init(conversationID: UUID, messages: [LumiChatMessage]) {
        self.conversationID = conversationID
        self.messages = messages
    }
}

public protocol LumiSendMiddleware: Sendable {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext
}
