import Foundation

@MainActor
public protocol MessageManaging: AnyObject, ObservableObject {
    func messages(for conversationID: UUID) -> [Message]
    func message(id: UUID, in conversationID: UUID) -> Message?
    func lastMessage(in conversationID: UUID) -> Message?
    func messageCount(for conversationID: UUID) -> Int
    func insertMessage(_ message: Message, to conversationID: UUID)
    func updateMessage(id: UUID, in conversationID: UUID, content: String)
    func deleteMessage(id: UUID, in conversationID: UUID)
    func clearMessages(in conversationID: UUID)
}
