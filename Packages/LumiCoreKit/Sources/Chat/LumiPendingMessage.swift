import Foundation

public struct LumiPendingMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let content: String
    public let imageAttachments: [LumiImageAttachment]

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        content: String,
        imageAttachments: [LumiImageAttachment] = []
    ) {
        self.id = id
        self.conversationID = conversationID
        self.content = content
        self.imageAttachments = imageAttachments
    }
}
