import Foundation

extension Notification.Name {
    static let conversationDidChange = Notification.Name("ChatHistoryService.ConversationDidChange")
}

enum ConversationChangeType: String {
    case created
    case updated
    case deleted
}

enum ConversationChangeUserInfoKey {
    static let type = "type"
    static let conversationId = "conversationId"
}
