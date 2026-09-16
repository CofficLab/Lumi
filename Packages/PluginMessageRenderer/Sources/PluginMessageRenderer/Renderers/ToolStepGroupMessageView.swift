import Foundation
import KitAgentTool
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import SwiftUI

/// 工具步骤组合成消息的渲染分发。
///
/// 数据层(`MessageListRowBuilder`)把连续多条「只含工具调用的助手消息」合并成一条
/// `renderKind == "tool-step-group"` 或 `"turn-activity"` 的合成消息。
/// V1/V2/V3 统一复用 `AssistantMessageView`：V1 由助手视图内部隐藏 Header，
/// 正文与工具调用内容保持 V2 一致。
///
/// View 只依赖 `MessageRendererCapability` 与 `MessageRendererStateViewModel`。
struct ToolStepGroupMessageView: View {
    let capability: any MessageRendererCapability
    @ObservedObject var stateViewModel: MessageRendererStateViewModel
    let message: Message
    let verbosity: ResponseVerbosity

    var body: some View {
        AssistantMessageView(
            capability: capability,
            stateViewModel: stateViewModel,
            message: message,
            verbosity: verbosity
        )
    }
}
