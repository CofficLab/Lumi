import Foundation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 磁盘测速卡片消息的渲染器。
///
/// order 高于 `core-system-message`（150）与 `core-default-markdown`，
/// 确保卡片消息不会被通用渲染器接管。
///
/// 渲染器只负责「把消息画成卡片」；它不关心这条消息是怎么来的。
enum DiskSpeedCardRenderer {
    /// 构造渲染器条目。
    ///
    /// - Parameter order: 渲染优先级，数值越大越优先。
    @MainActor
    static func item(order: Int) -> MessageRendererItem {
        MessageRendererItem(
            id: DiskSpeedTimeline.rendererID,
            order: order,
            canRender: { message in
                MessageTimelineEvent.isDiskSpeed(message)
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
        if let payload = DiskSpeedTimeline.decodePayload(from: message.content) {
            DiskSpeedCardView(payload: payload)
        } else {
            DiskSpeedCardFallbackView(message: message)
        }
    }
}
