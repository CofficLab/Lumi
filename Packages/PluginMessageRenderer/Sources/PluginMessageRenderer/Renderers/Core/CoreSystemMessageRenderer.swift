import Foundation
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 系统消息渲染器。
enum CoreSystemMessageRenderer {
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
            id: "core-system-message",
            order: baseOrder + 150,
            canRender: { message in
                message.role == .system
            },
            render: { [capability] message, verbosity in
                let view = AnyView(
                    verbosity == .chatGPT
                        ? AnyView(ChatGPTTimelineMarkerView(message: message))
                        : verbosity == .zcode
                            ? AnyView(ZCodeTimelineMarkerView(message: message))
                            : AnyView(SystemMessageView(
                                message: message,
                                verbosity: verbosity
                            ))
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
