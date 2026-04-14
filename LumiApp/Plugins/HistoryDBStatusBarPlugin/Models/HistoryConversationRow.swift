import Foundation

struct HistoryConversationRow: Identifiable {
    let id: UUID
    let title: String
    let projectId: String
    let createdAt: Date
    let updatedAt: Date
    let messageCount: Int
}
