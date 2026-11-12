import Foundation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 回合结束标记渲染器。
///
/// 优先级最高的渲染器：它只接管「回合刚结束」的那条时间线消息。
enum CoreTurnCompletedRenderer {
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
            id: "core-turn-completed",
            order: baseOrder + 320,
            canRender: { message in
                message.renderKind == "turn-completed" || message.content == LumiChatMarkers.turnCompleted
            },
            render: { [capability] message, verbosity in
                let view = AnyView(
                    verbosity == .chatGPT
                        ? AnyView(ChatGPTTimelineMarkerView(message: message))
                        : verbosity == .zcode
                            ? AnyView(ZCodeTimelineMarkerView(message: message))
                            : AnyView(TurnCompletedMessageView(message: message))
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
