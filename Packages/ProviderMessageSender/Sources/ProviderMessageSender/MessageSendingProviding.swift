import Foundation

@MainActor
public protocol MessageSendingProviding: AnyObject, ObservableObject {
    var isSending: Bool { get }
    func sendMessage(_ content: String, conversationID: UUID?) async throws
    func cancelCurrentRequest()
}
