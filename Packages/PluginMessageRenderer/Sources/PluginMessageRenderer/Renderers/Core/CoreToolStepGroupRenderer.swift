import Foundation
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 工具步骤组合成消息的渲染器。
///
/// 数据层把连续多条「只含工具调用的助手消息」合并成一条。
/// 优先级高于普通助手消息：V1 走可折叠步骤组，V2/V3 复用助手气泡。
enum CoreToolStepGroupRenderer {
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
            id: "core-tool-step-group",
            order: baseOrder + 185,
            canRender: { message in
                message.renderKind == "tool-step-group" || message.renderKind == "turn-activity"
            },
            render: { [capability, stateViewModel] message, verbosity in
                let view = AnyView(ToolStepGroupMessageView(
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
