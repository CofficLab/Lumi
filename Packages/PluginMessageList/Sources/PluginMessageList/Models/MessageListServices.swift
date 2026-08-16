import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderMessageStreaming
import ProviderToolManager

/// 新版 PluginMessageList 的服务容器。
///
/// 旧版 ViewModel 直接持有 `KernelLumi` 并访问 `kernel.messageManager` 等；
/// 新版改为在插件 `onBoot` 时解析全部 Provider，集中在这里传给各视图模型。
/// 全部为可选，允许部分 Provider 尚未注入时优雅降级（与旧版一致）。
@MainActor
struct MessageListServices {
    let conversations: (any ConversationManaging)?
    let messages: (any MessageManaging)?
    let rendering: (any MessageRenderingProviding)?
    let sender: (any MessageSendingProviding)?
    let streaming: (any MessageStreamingProviding)?
    let toolManager: (any ToolManagerProviding)?
    let agentTurn: (any AgentLoopProviding)?

    var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
    }
}
