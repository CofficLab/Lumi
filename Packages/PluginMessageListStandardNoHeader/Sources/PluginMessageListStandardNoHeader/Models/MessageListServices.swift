import Foundation
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
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
    let developerModeState: DeveloperModeStateViewModel
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

    /// 用户可见文案的解析器，默认走本模块的本地化目录。
    ///
    /// 注入点用于回归测试：锁住「文案一定经过本地化」，同时让断言
    /// 不依赖运行机器的系统语言。
    var resolveText: (String) -> String = { pluginLocalization.string($0) }

    var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    var activeChatContext: ChatContext? {
        chat?.activeContext
    }

    /// 返回一个替换了文案解析器的副本。
    ///
    /// `MessageListServices` 是值类型且 `resolveText` 是 `var`，因此需要
    /// 显式复制才能注入解析器 —— 测试与预览用它替换默认解析器。
    func withResolver(_ resolve: @escaping (String) -> String) -> MessageListServices {
        var copy = self
        copy.resolveText = resolve
        return copy
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
    }

    /// 构造活动状态行。
    func activityMessage(for conversationID: UUID?) -> Message? {
        guard let conversationID,
              let conversationState else { return nil }
        let state = conversationState.state(for: conversationID)
        guard let activity = state.activity else { return nil }
        let content: String
        switch activity {
        case .sending: content = resolveText("Sending message…")
        case .thinking: content = resolveText("Thinking…")
        case .executingTool:
            if let description = state.jobActivity.recentJobDescription,
               state.jobActivity.runningJobCount > 0 {
                content = String(format: resolveText("Running %@…"), description)
            } else {
                content = resolveText("Executing tool…")
            }
        case .waitingForUser: content = resolveText("Waiting for your input…")
        }
        return Message(conversationID: conversationID, role: .status, content: content)
    }

}
