import Foundation

public struct LumiSendContext: Sendable {
    public let conversationID: UUID
    public var messages: [LumiChatMessage]
    public var systemPromptFragments: [String]

    public init(
        conversationID: UUID,
        messages: [LumiChatMessage],
        systemPromptFragments: [String] = []
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.systemPromptFragments = systemPromptFragments
    }
}

public protocol LumiSendMiddleware: Sendable {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext
}
