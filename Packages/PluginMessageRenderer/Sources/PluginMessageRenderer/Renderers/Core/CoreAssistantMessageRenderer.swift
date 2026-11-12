import Foundation
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 助手消息渲染器。
enum CoreAssistantMessageRenderer {
    /// 构造渲染器条目。
    ///
    /// - Parameters:
    ///   - capability: 消息行可发起的外部操作集合。
    ///   - stateViewModel: 消息渲染器共享的界面状态。
    ///   - baseOrder: 渲染优先级基数。
    @MainActor
    static func item(
        capability: any MessageRendererCapability,
        stateViewModel: MessageRendererStateViewModel,
        baseOrder: Int
    ) -> MessageRendererItem {
        MessageRendererItem(
            id: "core-assistant-message",
            order: baseOrder + 180,
            canRender: { message in
                message.role == .assistant
            },
            render: { [capability, stateViewModel] message, verbosity in
                let view = AnyView(AssistantMessageView(
                    capability: capability,
                    stateViewModel: stateViewModel,
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
