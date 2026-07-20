import Foundation
import LumiKernel

public struct ConversationListItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let projectPath: String?
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
    public let providerID: String?
    public let modelName: String?

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LumiPluginLocalization.string("Untitled", bundle: .module) : trimmed
    }

    public init(
        id: UUID,
        projectPath: String?,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        providerID: String? = nil,
        modelName: String? = nil
    ) {
        self.id = id
        self.projectPath = projectPath
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerID = providerID
        self.modelName = modelName
    }

    static func from(_ summary: LumiConversationSummary) -> ConversationListItem {
        ConversationListItem(
            id: summary.id,
            projectPath: summary.projectPath,
            title: summary.title,
            createdAt: summary.createdAt,
            updatedAt: summary.updatedAt,
            providerID: summary.providerID,
            modelName: summary.modelName
        )
    }
}

public struct ConversationListChange: Equatable, Sendable {
    public enum ChangeType: Sendable {
        case created
        case updated
        case deleted
    }

    public let type: ChangeType
    public let conversationId: UUID

    public init(type: ChangeType, conversationId: UUID) {
        self.type = type
        self.conversationId = conversationId
    }
}
