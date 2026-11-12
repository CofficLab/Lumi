import Foundation
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 兜底渲染器：order 最低，只要没有任何更高优先级的渲染器能处理，就由它接管。
enum CoreDefaultMarkdownRenderer {
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
            id: "core-default-markdown",
            order: baseOrder - 10,
            canRender: { _ in true },
            render: { [capability] message, verbosity in
                let view = AnyView(
                    verbosity == .chatGPT
                        ? AnyView(ChatGPTDefaultMessageView(message: message, verbosity: verbosity))
                        : verbosity == .zcode
                            ? AnyView(ZCodeTimelineMarkerView(message: message))
                            : AnyView(DefaultMessageView(
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
