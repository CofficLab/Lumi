import Foundation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 状态消息渲染器。
///
/// 优先级低于具体的状态类渲染器（turn-completed 等），但高于通用系统消息。
enum CoreStatusMessageRenderer {
    /// 构造渲染器条目。
    ///
    /// - Parameters:
    ///   - capability: 消息行可发起的外部操作集合。
    ///   - baseOrder: 渲染优先级基数。
    @MainActor
    static func item(
        capability: any MessageRendererCapability,
        baseOrder: Int
    ) -> MessageRendererItem {
        MessageRendererItem(
            id: "core-status-message",
            order: baseOrder + 310,
            canRender: { message in
                message.role == .status
                    && message.renderKind != "turn-completed"
                    && message.content != LumiChatMarkers.turnCompleted
            },
            render: { [capability] message, verbosity in
                let view = AnyView(
                    verbosity == .chatGPT
                        ? AnyView(ChatGPTTimelineMarkerView(message: message))
                        : verbosity == .zcode
                            ? AnyView(ZCodeTimelineMarkerView(message: message))
                            : AnyView(StatusMessageView(message: message, verbosity: verbosity))
                )
                return CoreMessageRenderer.attachMenu(
                    to: view,
                    capability: capability,
                    message: message
                )
            }
        )
    }
}
