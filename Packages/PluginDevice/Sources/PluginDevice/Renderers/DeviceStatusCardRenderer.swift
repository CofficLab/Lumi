import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 设备状态卡片消息的渲染器。
///
/// order 高于 `core-system-message`（base + 150 = 160），确保卡片消息
/// 不会被通用系统消息渲染器接管——否则用户看到的是一行纯文本而不是卡片。
///
/// 渲染器只负责「把消息画成卡片」；它不关心这条消息是怎么来的。
enum DeviceStatusCardRenderer {
    /// 构造渲染器条目。
    ///
    /// - Parameter order: 渲染优先级，数值越大越优先。
    @MainActor
    static func item(order: Int) -> MessageRendererItem {
        MessageRendererItem(
            id: DeviceStatusTimeline.rendererID,
            order: order,
            canRender: { message in
                MessageTimelineEvent.isDeviceStatus(message)
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
        if let payload = DeviceStatusTimeline.decodePayload(from: message.content) {
            DeviceStatusCardView(payload: payload)
        } else {
            DeviceStatusCardFallbackView(message: message)
        }
    }
}
