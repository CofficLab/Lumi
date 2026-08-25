import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import SwiftUI

/// 工具步骤组合成消息的渲染分发。
///
/// 数据层(`MessageListRowBuilder`)把连续多条「只含工具调用的助手消息」合并成一条
/// `renderKind == "tool-step-group"` 或 `"turn-activity"` 的合成消息。
/// 本视图按 verbosity 分流渲染:
/// - **V1 (brief)**:走 `CollapsibleToolStepGroup`,默认收起成一行摘要。
/// - **V2/V3**:复用现有 `AssistantMessageView` —— 多个工具卡片聚合在同一个助手气泡里,
///   只剩一个消息头(而非之前的 N 个独立气泡)。
struct ToolStepGroupMessageView: View {
    let kernel: KernelCoreContainer
    let message: Message
    let verbosity: LumiResponseVerbosity

    var body: some View {
        if verbosity == .brief {
            CollapsibleToolStepGroup(
                kernel: kernel,
                message: message,
                toolCalls: message.toolCalls ?? [],
                verbosity: verbosity
            )
        } else {
            AssistantMessageView(kernel: kernel, message: message, verbosity: verbosity)
        }
    }
}
