import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI
import KitMessageList

/// V5（ChatGPT）单条消息行。
///
/// 通过注入的渲染器分发到具体视图；没有渲染器时给出降级提示。
///
/// - Important: `verbosity` 由上层计算并显式传入，再由
///   `MessageRendererItem.render` 闭包转发给具体视图。
/// - Important: 轮次呈现上下文只通过 SwiftUI Environment 传给 renderer，
///   **不修改** `MessageRenderingProviding.MessageRendererItem.render` 的签名，
///   因此第三方 renderer 无需改动。
struct MessageRowView: View {
    let services: MessageListServices
    let message: Message
    let verbosity: ResponseVerbosity

    /// 轮次呈现上下文。
    ///
    /// - Important: V5 始终传入这个参数；它只影响 V5 自己的呈现。
    let turnContext: MessageTurnPresentationContext?

    init(
        services: MessageListServices,
        message: Message,
        verbosity: ResponseVerbosity,
        turnContext: MessageTurnPresentationContext? = nil
    ) {
        self.services = services
        self.message = message
        self.verbosity = verbosity
        self.turnContext = turnContext
    }

    private var renderer: MessageRendererItem? {
        services.rendering?.renderer(for: message)
    }

    var body: some View {
        Group {
            if let renderer {
                renderer.render(message, verbosity)
                    .environment(\.messageTurnPresentation, turnContext)
            } else {
                Text("No renderer for message: \(message.id)")
                    .foregroundColor(.orange)
                    .padding(12)
            }
        }
    }
}
