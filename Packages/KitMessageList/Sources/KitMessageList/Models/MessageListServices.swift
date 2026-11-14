import Foundation
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderDeveloperMode
import ProviderMessage

/// 消息列表插件共享的服务容器。
///
/// 插件 `onBoot` 时解析全部 Provider，经 `Capabilities/` 收窄为最小能力协议后
/// 集中在这里传给各视图模型。全部为可选，允许部分 Provider 尚未注入时优雅降级。
///
/// 参数顺序与各插件既有的构造调用保持一致；插件用不到的字段省略即可。
@MainActor
public struct MessageListServices {
    public let conversations: (any MessageListConversationCapability)?
    public let conversationState: (any MessageListConversationStateCapability)?
    public let developerMode: (any MessageListDeveloperModeCapability)?
    public let developerModeState: DeveloperModeStateViewModel
    public let messages: (any MessageListMessageCapability)?
    public let rendering: (any MessageListRenderingCapability)?
    public let streaming: (any MessageListStreamingCapability)?
    public let toolManager: (any MessageListToolManagerCapability)?
    public let agentTurn: (any MessageListAgentLoopCapability)?
    public let promptSuggestions: (any MessageListPromptSuggestionCapability)?
    public let promptSuggestionExecutor: (any MessageListPromptSuggestionExecutorCapability)?
    public let project: (any MessageListProjectCapability)?
    public let toolbar: (any MessageListToolbarCapability)?
    public let chat: (any MessageListChatSectionCapability)?

    /// 用户可见文案的解析器，默认走 Kit 的本地化目录。
    ///
    /// 注入点用于回归测试：锁住「文案一定经过本地化」，同时让断言
    /// 不依赖运行机器的系统语言。
    public var resolveText: (String) -> String = { messageListLocalization.string($0) }

    public init(
        conversations: (any MessageListConversationCapability)? = nil,
        conversationState: (any MessageListConversationStateCapability)? = nil,
        developerMode: (any MessageListDeveloperModeCapability)? = nil,
        developerModeState: DeveloperModeStateViewModel = DeveloperModeStateViewModel(),
        messages: (any MessageListMessageCapability)? = nil,
        rendering: (any MessageListRenderingCapability)? = nil,
        streaming: (any MessageListStreamingCapability)? = nil,
        toolManager: (any MessageListToolManagerCapability)? = nil,
        agentTurn: (any MessageListAgentLoopCapability)? = nil,
        promptSuggestions: (any MessageListPromptSuggestionCapability)? = nil,
        promptSuggestionExecutor: (any MessageListPromptSuggestionExecutorCapability)? = nil,
        project: (any MessageListProjectCapability)? = nil,
        toolbar: (any MessageListToolbarCapability)? = nil,
        chat: (any MessageListChatSectionCapability)? = nil
    ) {
        self.conversations = conversations
        self.conversationState = conversationState
        self.developerMode = developerMode
        self.developerModeState = developerModeState
        self.messages = messages
        self.rendering = rendering
        self.streaming = streaming
        self.toolManager = toolManager
        self.agentTurn = agentTurn
        self.promptSuggestions = promptSuggestions
        self.promptSuggestionExecutor = promptSuggestionExecutor
        self.project = project
        self.toolbar = toolbar
        self.chat = chat
    }

    public var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    public var activeChatContext: ChatContext? {
        chat?.activeContext
    }

    /// 返回一个替换了文案解析器的副本。
    ///
    /// `MessageListServices` 是值类型且 `resolveText` 是 `var`，因此需要
    /// 显式复制才能注入解析器 —— 测试与预览用它替换默认解析器。
    public func withResolver(_ resolve: @escaping (String) -> String) -> MessageListServices {
        var copy = self
        copy.resolveText = resolve
        return copy
    }

    public func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
    }

    /// 构造活动状态行。
    public func activityMessage(for conversationID: UUID?) -> Message? {
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
