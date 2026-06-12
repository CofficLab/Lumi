import Foundation
import LumiCoreKit

public struct ConversationListItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let projectPath: String?
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LumiPluginLocalization.string("Untitled", bundle: .module) : trimmed
    }

    public init(
        id: UUID,
        projectPath: String?,
        title: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.projectPath = projectPath
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func from(_ summary: LumiConversationSummary) -> ConversationListItem {
        ConversationListItem(
            id: summary.id,
            projectPath: summary.projectPath,
            title: summary.title,
            createdAt: summary.createdAt,
            updatedAt: summary.updatedAt
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
