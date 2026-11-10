import Foundation
import ProviderMessage
import ProviderMessageStreaming

/// 流式消息展示所需的最小流式能力。
///
/// - Note: 能力面刻意**不含** `start` / `append` / `end` ——
///   那是**写入**侧的能力，属于 AgentLoop 与 Provider 的职责。
///   消息列表只**读**流式状态，不参与产生流式内容。
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
