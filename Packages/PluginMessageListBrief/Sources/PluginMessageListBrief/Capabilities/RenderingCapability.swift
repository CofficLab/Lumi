import ProviderMessage
import ProviderMessageRendering

/// 消息渲染所需的最小渲染能力。
@MainActor
protocol MessageListRenderingCapability: AnyObject {
    func renderer(for message: Message) -> MessageRendererItem?
}

@MainActor
final class MessageListRenderingCapabilityAdapter: MessageListRenderingCapability {
    private let rendering: any MessageRenderingProviding

    init(rendering: any MessageRenderingProviding) {
        self.rendering = rendering
    }

    func renderer(for message: Message) -> MessageRendererItem? {
        rendering.renderer(for: message)
    }
}
