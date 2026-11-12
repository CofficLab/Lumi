import Foundation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// HTML 卡片的消息渲染器。
///
/// 把带 `renderKind = "html-canvas"` 的时间线消息画成一张卡片。
enum HTMLCanvasRenderer {

    /// 构造渲染器条目。
    ///
    /// - Parameter order: 渲染优先级。必须高于核心的 `core-system-message`
    ///   （base + 150 = 160）：卡片消息是 `role = .system`，若优先级低于它
    ///   就会被通用系统消息渲染器接管，用户看到的是一行纯文本而不是卡片。
    @MainActor
    static func item(order: Int) -> MessageRendererItem {
        MessageRendererItem(
            id: HTMLCanvasTimeline.rendererID,
            order: order,
            canRender: { message in
                MessageTimelineEvent.isHTMLCanvas(message)
            },
            render: { message, _ in
                AnyView(view(for: message))
            }
        )
    }

    /// 按消息构造对应视图。
    ///
    /// 载荷缺失时回退到纯文本摘要，避免渲染空白。
    @MainActor
    @ViewBuilder
    private static func view(for message: Message) -> some View {
        if let payload = HTMLCanvasTimeline.decodePayload(from: message.metadata) {
            HTMLCanvasCardView(payload: payload)
        } else {
            HTMLCanvasFallbackView(message: message)
        }
    }
}
