import Foundation
import ProviderMessage
import ProviderMessageStreaming

/// 流式消息展示所需的最小流式能力。
@MainActor
protocol MessageListStreamingCapability: AnyObject {
    func streamingMessage(for conversationID: UUID) -> Message?
    func stage(for conversationID: UUID) -> MessageStreamingStage
}

@MainActor
final class MessageListStreamingCapabilityAdapter: MessageListStreamingCapability {
    private let streaming: any MessageStreamingProviding

    init(streaming: any MessageStreamingProviding) {
        self.streaming = streaming
    }

    func streamingMessage(for conversationID: UUID) -> Message? {
        streaming.streamingMessage(for: conversationID)
    }

    func stage(for conversationID: UUID) -> MessageStreamingStage {
        streaming.stage(for: conversationID)
    }
}
