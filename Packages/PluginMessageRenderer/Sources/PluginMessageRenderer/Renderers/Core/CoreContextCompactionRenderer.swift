import Foundation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 上下文压缩标记渲染器。
enum CoreContextCompactionRenderer {
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
            id: "core-context-compaction",
            order: baseOrder + 315,
            canRender: { message in
                MessageTimelineEvent.isContextCompaction(message)
            },
            render: { [capability] message, verbosity in
                let view = AnyView(
                    verbosity == .chatGPT
                        ? AnyView(ChatGPTTimelineMarkerView(message: message))
                        : verbosity == .zcode
                            ? AnyView(ZCodeTimelineMarkerView(message: message))
                            : AnyView(ContextCompactionMessageView(message: message))
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
