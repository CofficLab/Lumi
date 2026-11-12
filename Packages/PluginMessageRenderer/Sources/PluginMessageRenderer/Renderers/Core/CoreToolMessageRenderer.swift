import Foundation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 工具结果消息渲染器。
enum CoreToolMessageRenderer {
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
            id: "core-tool-message",
            order: baseOrder + 240,
            canRender: { message in
                message.role == .tool
            },
            render: { [capability] message, verbosity in
                let view = AnyView(ToolMessageView(
                    message: message,
                    verbosity: verbosity
                ))
                return CoreMessageRenderer.attachMenu(
                    to: view,
                    capability: capability,
                    message: message
                )
            }
        )
    }
}
