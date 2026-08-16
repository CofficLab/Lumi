import Combine
import Foundation
import ProviderMessage

public enum MessageStreamingStage: String, Sendable { case idle, sending, thinking, generating }
@MainActor
public protocol MessageStreamingProviding: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    func streamingMessage(for conversationID: UUID) -> Message?
    func stage(for conversationID: UUID) -> MessageStreamingStage
    func start(conversationID: UUID)
    func appendContent(_ content: String, conversationID: UUID)
    func appendThinking(_ content: String, conversationID: UUID)
    func end(conversationID: UUID)
}

@MainActor
public final class DefaultMessageStreamingProviding: MessageStreamingProviding {
    @Published private var rows: [UUID: Message] = [:]
    private var stages: [UUID: MessageStreamingStage] = [:]
    public init() {}
    public func streamingMessage(for conversationID: UUID) -> Message? { rows[conversationID] }
    public func stage(for conversationID: UUID) -> MessageStreamingStage { stages[conversationID] ?? .idle }
    public func start(conversationID: UUID) { rows[conversationID] = Message(conversationID: conversationID, role: .assistant, content: ""); stages[conversationID] = .sending }
    public func appendContent(_ content: String, conversationID: UUID) { guard var row = rows[conversationID] else { return }; row.content += content; rows[conversationID] = row; stages[conversationID] = .generating }
    public func appendThinking(_ content: String, conversationID: UUID) { stages[conversationID] = .thinking }
    public func end(conversationID: UUID) { rows[conversationID] = nil; stages[conversationID] = .idle }
}
