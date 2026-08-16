import Combine
import Foundation
import ProviderMessage

public enum MessageStreamingStage: String, Sendable { case idle, sending, thinking, generating }

/// 流式输出 store（KernelCore 体系）。
///
/// `@MainActor` 约束与 `MessageManaging` / `ConversationManaging` 一致：流式行
/// 由 AgentLoop 在回合循环中写入，UI 窄播订阅；`any MessageStreamingProviding`
/// 因此是 MainActor 隔离的存在类型，可在 `@Sendable` 流式回调中经 `await` 安全访问。
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
