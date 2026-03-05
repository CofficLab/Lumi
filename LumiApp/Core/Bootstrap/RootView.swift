import SwiftData
import SwiftUI

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// SwiftData 模型容器
    let modelContainer: ModelContainer

    /// AgentProvider
    let agentProvider: AgentProvider

    /// 会话 ViewModel
    let conversationViewModel: ConversationViewModel

    /// 消息 ViewModel
    let messageViewModel: MessageViewModel

    /// 消息发送 ViewModel
    let messageSenderViewModel: MessageSenderViewModel

    /// 命令建议 ViewModel
    let commandSuggestionViewModel: CommandSuggestionViewModel

    init(@ViewBuilder content: () -> Content) {
        self.content = content()

        // 初始化 SwiftData 容器
        self.modelContainer = AppConfig.getContainer()

        // 初始化聊天历史服务
        ChatHistoryService.shared.initializeWithContainer(self.modelContainer, reason: "主窗口初始化")

        // 初始化 ViewModel
        self.agentProvider = AgentProvider()
        self.conversationViewModel = ConversationViewModel.shared
        self.messageViewModel = MessageViewModel.shared
        self.commandSuggestionViewModel = CommandSuggestionViewModel.shared

        // 初始化消息发送 ViewModel（注入依赖）
        self.messageSenderViewModel = MessageSenderViewModel(
            messageViewModel: messageViewModel,
            conversationViewModel: conversationViewModel,
            agentProvider: agentProvider
        )

        // 设置 ViewModel 引用
        agentProvider.messageViewModel = messageViewModel
        agentProvider.conversationViewModel = conversationViewModel
        agentProvider.messageSenderViewModel = messageSenderViewModel

        // 设置 ConversationViewModel 的 AgentProvider 引用
        conversationViewModel.agentProvider = agentProvider
    }

    var body: some View {
        content
            .environmentObject(agentProvider)
            .environmentObject(PluginProvider.shared)
            .environmentObject(conversationViewModel)
            .environmentObject(messageViewModel)
            .environmentObject(messageSenderViewModel)
            .environmentObject(commandSuggestionViewModel)
            .environmentObject(MystiqueThemeManager())
            .modelContainer(modelContainer)
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Returns: 包装在 RootView 中的视图
    func inRootView() -> some View {
        AnyView(RootView(content: { self }, reason: "RootView"))
    }
}

extension RootView {
    /// 初始化 RootView，支持传入初始化原因
    init(@ViewBuilder content: () -> Content, reason: String) {
        self.content = content()

        // 初始化 SwiftData 容器
        self.modelContainer = AppConfig.getContainer()

        // 初始化聊天历史服务
        ChatHistoryService.shared.initializeWithContainer(self.modelContainer, reason: reason)

        // 初始化 ViewModel
        self.agentProvider = AgentProvider()
        self.conversationViewModel = ConversationViewModel.shared
        self.messageViewModel = MessageViewModel.shared
        self.commandSuggestionViewModel = CommandSuggestionViewModel.shared

        // 初始化消息发送 ViewModel（注入依赖）
        self.messageSenderViewModel = MessageSenderViewModel(
            messageViewModel: messageViewModel,
            conversationViewModel: conversationViewModel,
            agentProvider: agentProvider
        )

        // 设置 ViewModel 引用
        agentProvider.messageViewModel = messageViewModel
        agentProvider.conversationViewModel = conversationViewModel
        agentProvider.messageSenderViewModel = messageSenderViewModel

        // 设置 ConversationViewModel 的 AgentProvider 引用
        conversationViewModel.agentProvider = agentProvider
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
