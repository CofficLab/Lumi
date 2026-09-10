import Foundation
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderDeveloperMode
import ProviderMessage

/// 新版 PluginMessageList 的服务容器。
///
/// 旧版 ViewModel 直接持有 `KernelLumi` 并访问 `kernel.messageManager` 等；
/// 新版改为在插件 `onBoot` 时解析全部 Provider，经 `Capabilities/` 收窄为
/// 最小能力协议后集中在这里传给各视图模型。
/// 全部为可选，允许部分 Provider 尚未注入时优雅降级（与旧版一致）。
@MainActor
struct MessageListServices {
    let conversations: (any MessageListConversationCapability)?
    let conversationState: (any MessageListConversationStateCapability)?
    let developerMode: (any DeveloperModeProviding)?
    let messages: (any MessageListMessageCapability)?
    let rendering: (any MessageListRenderingCapability)?
    let streaming: (any MessageListStreamingCapability)?
    let toolManager: (any MessageListToolManagerCapability)?
    let agentTurn: (any MessageListAgentLoopCapability)?
    let promptSuggestions: (any MessageListPromptSuggestionCapability)?
    let promptSuggestionExecutor: (any MessageListPromptSuggestionExecutorCapability)?
    let project: (any MessageListProjectCapability)?
    let toolbar: (any MessageListToolbarCapability)?
    let chat: (any MessageListChatSectionCapability)?
    var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    var activeChatContext: ChatContext? {
        chat?.activeContext
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
    }

    func activityMessage(for conversationID: UUID?) -> Message? {
        guard let conversationID,
              let conversationState else { return nil }
        let state = conversationState.state(for: conversationID)
        guard let activity = state.activity else { return nil }
        let content: String
        switch activity {
        case .sending: content = String(localized: "status.sending", defaultValue: "正在发送消息…")
        case .thinking: content = String(localized: "status.thinking", defaultValue: "正在思考…")
        case .executingTool:
            if let description = state.jobActivity.recentJobDescription,
               state.jobActivity.runningJobCount > 0 {
                content = "正在\(description)…"
            } else {
                content = String(localized: "status.executing-tool", defaultValue: "正在执行工具…")
            }
        case .waitingForUser: content = String(localized: "status.waiting-for-user", defaultValue: "等待你的输入…")
        }
        return Message(conversationID: conversationID, role: .status, content: content)
    }

}
