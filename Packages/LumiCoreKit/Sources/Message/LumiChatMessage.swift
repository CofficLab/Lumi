import Foundation

public struct LumiChatMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let role: LumiChatMessageRole
    public var content: String
    public let createdAt: Date
    public var providerID: String?
    public var modelName: String?
    public var isError: Bool
    public var rawErrorDetail: String?
    public var renderKind: String?
    public var metadata: [String: String]
    public var toolCalls: [LumiToolCall]?
    public var toolCallID: String?
    public var reasoningContent: String?

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: LumiChatMessageRole,
        content: String,
        createdAt: Date = Date(),
        providerID: String? = nil,
        modelName: String? = nil,
        isError: Bool = false,
        rawErrorDetail: String? = nil,
        renderKind: String? = nil,
        metadata: [String: String] = [:],
        toolCalls: [LumiToolCall]? = nil,
        toolCallID: String? = nil,
        reasoningContent: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.providerID = providerID
        self.modelName = modelName
        self.isError = isError
        self.rawErrorDetail = rawErrorDetail
        self.renderKind = renderKind
        self.metadata = metadata
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.reasoningContent = reasoningContent
    }
}
