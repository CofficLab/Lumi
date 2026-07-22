import Foundation

public struct LumiSendContext: Sendable {
    public let conversationID: UUID
    public var messages: [LumiChatMessage]
    public var systemPromptFragments: [String]
    public var currentProjectPath: String
    public var conversationTitle: String
    public var conversationLanguage: LumiConversationLanguage

    public init(
        conversationID: UUID,
        messages: [LumiChatMessage],
        systemPromptFragments: [String] = [],
        currentProjectPath: String = "",
        conversationTitle: String = "",
        conversationLanguage: LumiConversationLanguage = .chinese
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.systemPromptFragments = systemPromptFragments
        self.currentProjectPath = currentProjectPath
        self.conversationTitle = conversationTitle
        self.conversationLanguage = conversationLanguage
    }
}

public protocol LumiSendMiddleware: Sendable {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext
}
