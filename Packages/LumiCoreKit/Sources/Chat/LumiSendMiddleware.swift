import Foundation

public struct LumiSendContext: Sendable {
    public let conversationID: UUID
    public var messages: [LumiChatMessage]
    public var systemPromptFragments: [String]
    public var currentProjectPath: String

    public init(
        conversationID: UUID,
        messages: [LumiChatMessage],
        systemPromptFragments: [String] = [],
        currentProjectPath: String = ""
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.systemPromptFragments = systemPromptFragments
        self.currentProjectPath = currentProjectPath
    }
}

public protocol LumiSendMiddleware: Sendable {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext
}
