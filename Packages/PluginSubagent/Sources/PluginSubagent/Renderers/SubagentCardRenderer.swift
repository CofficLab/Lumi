import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI

/// 子代理委托卡片消息的渲染器（#1313 Task 6）。
///
/// order 由插件入口按 `order` 派生，确保卡片消息不被通用渲染器接管。
///
/// 渲染器只负责「把消息画成卡片」；实时状态由卡片视图经工具管理器读取，
/// 它不关心这条消息是怎么来的。
enum SubagentCardRenderer {
    /// 构造渲染器条目。
    ///
    /// - Parameters:
    ///   - order: 渲染优先级，数值越大越优先。
    ///   - toolManagerProvider: 工具管理器解析闭包；缺席时卡片只显示静态信息。
    @MainActor
    static func item(
        order: Int,
        toolManagerProvider: @escaping @MainActor @Sendable () -> (any ToolManagerProviding)?
    ) -> MessageRendererItem {
        MessageRendererItem(
            id: SubagentTimeline.rendererID,
            order: order,
            canRender: { message in
                MessageTimelineEvent.isSubagentDelegation(message)
            },
            render: { message, _ in
                AnyView(view(for: message, toolManagerProvider: toolManagerProvider))
            }
        )
    }

    /// 按消息构造对应视图。
    ///
    /// 载荷缺失时回退到纯文本摘要，避免渲染空白。
    @MainActor
    @ViewBuilder
    private static func view(
        for message: Message,
        toolManagerProvider: @escaping @MainActor @Sendable () -> (any ToolManagerProviding)?
    ) -> some View {
        if let payload = SubagentTimeline.decodePayload(from: message.metadata) {
            SubagentCardView(payload: payload, toolManager: toolManagerProvider())
        } else {
            SubagentCardFallbackView(message: message)
        }
    }
}