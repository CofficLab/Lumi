import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// Finder 卡片消息的渲染器。
///
/// order 高于 `core-system-message`（150）与 `core-default-markdown`，
/// 确保卡片消息不会被通用渲染器接管。
///
/// 渲染器只负责「把消息画成卡片」以及把按钮点击转交给 Finder 打开服务；
/// 它不关心这条消息是怎么来的。
enum FinderCardRenderer {
    /// 构造渲染器条目。
    ///
    /// - Parameter order: 渲染优先级，数值越大越优先。
    @MainActor
    static func item(order: Int) -> MessageRendererItem {
        MessageRendererItem(
            id: FinderTimeline.rendererID,
            order: order,
            canRender: { message in
                MessageTimelineEvent.isFinder(message)
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
        if let payload = FinderTimeline.decodePayload(from: message.metadata) {
            FinderCardView(payload: payload) {
                FinderOpener.open(path: payload.path)
            }
        } else {
            FinderCardFallbackView(message: message)
        }
    }
}
