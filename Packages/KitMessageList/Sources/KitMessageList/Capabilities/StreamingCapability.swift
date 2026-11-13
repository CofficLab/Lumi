import Foundation
import ProviderMessage
import ProviderMessageStreaming

/// 流式消息展示所需的最小流式能力。
@MainActor
public protocol MessageListStreamingCapability: AnyObject {
    func streamingMessage(for conversationID: UUID) -> Message?
    func stage(for conversationID: UUID) -> MessageStreamingStage
}

@MainActor
public final class MessageListStreamingCapabilityAdapter: MessageListStreamingCapability {
    private let streaming: any MessageStreamingProviding
    public init(streaming: any MessageStreamingProviding) { self.streaming = streaming }
    public func streamingMessage(for conversationID: UUID) -> Message? {
        streaming.streamingMessage(for: conversationID)
    }
    public func stage(for conversationID: UUID) -> MessageStreamingStage {
        streaming.stage(for: conversationID)
    }
}