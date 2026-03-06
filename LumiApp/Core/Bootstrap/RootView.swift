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

    /// 应用提供者
    let appProvider: AppProvider

    /// 项目 ViewModel
    let projectViewModel: ProjectViewModel

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

        // 初始化聊天历史服务（非单例）
        let chatHistoryService = ChatHistoryService(
            llmService: LLMService.shared,
            modelContainer: self.modelContainer
        )

        // 初始化 ViewModel（非单例，使用依赖注入）
        self.appProvider = AppProvider()
        self.projectViewModel = ProjectViewModel()
        self.commandSuggestionViewModel = CommandSuggestionViewModel()
        
        // 创建 MessageViewModel
        self.messageViewModel = MessageViewModel(chatHistoryService: chatHistoryService)

        // 创建 ConversationViewModel（messageSenderViewModel 将在之后设置）
        self.conversationViewModel = ConversationViewModel(
            chatHistoryService: chatHistoryService,
            messageViewModel: messageViewModel
        )

        // 创建 MessageSenderViewModel
        self.messageSenderViewModel = MessageSenderViewModel(
            messageViewModel: messageViewModel,
            conversationViewModel: conversationViewModel,
            chatHistoryService: chatHistoryService
        )

        // 设置 ConversationViewModel 的 messageSenderViewModel 引用
        self.conversationViewModel.messageSenderViewModel = self.messageSenderViewModel

        // 初始化对话轮次 ViewModel
        let conversationTurnViewModel = ConversationTurnViewModel(
            llmService: LLMService.shared,
            toolManager: ToolManager.shared,
            promptService: PromptService.shared
        )

        // 初始化 AgentProvider（先创建，再注入到其他依赖中）
        self.agentProvider = AgentProvider(
            promptService: PromptService.shared,
            registry: ProviderRegistry.shared,
            toolManager: ToolManager.shared,
            chatHistoryService: chatHistoryService,
            messageViewModel: messageViewModel,
            conversationViewModel: conversationViewModel,
            messageSenderViewModel: self.messageSenderViewModel,
            projectViewModel: projectViewModel,
            conversationTurnViewModel: conversationTurnViewModel
        )

        // 设置委托和配置提供者
        self.messageSenderViewModel.delegate = self.agentProvider
        self.messageSenderViewModel.setConfigProvider(self.agentProvider)
        conversationTurnViewModel.delegate = self.agentProvider
    }

    var body: some View {
        content
            .environmentObject(appProvider)
            .environmentObject(agentProvider)
            .environmentObject(projectViewModel)
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
        AnyView(RootView(content: { self }))
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
