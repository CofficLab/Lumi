import Foundation
import SwiftData

@Model
final class AutoTitleGenerationRecord {
    @Attribute(.unique) var conversationId: UUID
    var createdAt: Date

    init(conversationId: UUID, createdAt: Date = Date()) {
        self.conversationId = conversationId
        self.createdAt = createdAt
    }
}

