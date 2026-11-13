import ProviderMessage
import ProviderMessageRendering

/// 消息渲染所需的最小渲染能力。
@MainActor
public protocol MessageListRenderingCapability: AnyObject {
    func renderer(for message: Message) -> MessageRendererItem?
}

@MainActor
public final class MessageListRenderingCapabilityAdapter: MessageListRenderingCapability {
    private let rendering: any MessageRenderingProviding
    public init(rendering: any MessageRenderingProviding) { self.rendering = rendering }
    public func renderer(for message: Message) -> MessageRendererItem? {
        rendering.renderer(for: message)
    }
}