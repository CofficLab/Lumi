import Foundation
import SwiftData

/// A persisted summary snapshot owned by the LLM context plugin.
@Model
final class ContextSummaryModel {
    /// One summary per conversation. New summaries replace the previous snapshot.
    @Attribute(.unique) var conversationID: UUID
    var summary: String
    var coveredThroughMessageID: UUID
    var sourceLastMessageID: UUID
    var providerID: String?
    var modelName: String?
    var sourceMessageCount: Int
    var updatedAt: Date
    var schemaVersion: Int

    init(
        conversationID: UUID,
        summary: String,
        coveredThroughMessageID: UUID,
        sourceLastMessageID: UUID,
        providerID: String?,
        modelName: String?,
        sourceMessageCount: Int,
        updatedAt: Date = Date(),
        schemaVersion: Int = 1
    ) {
        self.conversationID = conversationID
        self.summary = summary
        self.coveredThroughMessageID = coveredThroughMessageID
        self.sourceLastMessageID = sourceLastMessageID
        self.providerID = providerID
        self.modelName = modelName
        self.sourceMessageCount = sourceMessageCount
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }
}
