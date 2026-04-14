import Foundation

struct HistoryMessageRow: Identifiable {
    let id: UUID
    let conversationId: UUID
    let conversationTitle: String
    let role: String
    let model: String
    let tokens: Int
    let timestamp: Date
    let contentPreview: String
}
