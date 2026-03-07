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
    let appProvider: GlobalProvider

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

    /// 工具服务
    let toolService: ToolService

    /// Tools ViewModel
    let toolsViewModel: ToolsViewModel

    /// 上下文服务
    let contextService: ContextService

    /// 提示词服务
    let promptService: PromptService

    /// LLM 服务
    let llmService: LLMService

    /// Slash 命令服务
    let slashCommandService: SlashCommandService

    init(@ViewBuilder content: () -> Content) {
        self.content = content()

        // 初始化 SwiftData 容器
        self.modelContainer = AppConfig.getContainer()

        // ========================================
        // 基础服务层（无依赖或依赖最少）
        // ========================================

        // 初始化上下文服务
        self.contextService = ContextService()

        // 初始化 LLM 服务（内部自动初始化 APIService 和 LLMAPIService）
        self.llmService = LLMService()

        // 初始化提示词服务（依赖 ContextService）
        self.promptService = PromptService(contextService: contextService)

        // 初始化 Slash 命令服务
        self.slashCommandService = SlashCommandService()

        // 初始化工具服务
        self.toolService = ToolService()

        // ========================================
        // ViewModel 层
        // ========================================

        // 创建 Tools ViewModel
        self.toolsViewModel = ToolsViewModel(toolService: toolService)

        // 初始化聊天历史服务（依赖 LLMService）
        let chatHistoryService = ChatHistoryService(
            llmService: llmService,
            modelContainer: self.modelContainer
        )

        // 初始化基础 ViewModel
        self.appProvider = GlobalProvider()
        self.projectViewModel = ProjectViewModel(contextService: contextService)
        self.commandSuggestionViewModel = CommandSuggestionViewModel()

        // 创建 MessageViewModel
        self.messageViewModel = MessageViewModel(chatHistoryService: chatHistoryService)

        // 创建 ConversationViewModel（messageSenderViewModel 将在之后设置）
        self.conversationViewModel = ConversationViewModel(
            chatHistoryService: chatHistoryService,
            llmService: llmService,
            promptService: promptService,
            messageViewModel: messageViewModel
        )

        // 创建 MessageSenderViewModel
        self.messageSenderViewModel = MessageSenderViewModel(
            messageViewModel: messageViewModel,
            conversationViewModel: conversationViewModel,
            chatHistoryService: chatHistoryService,
            slashCommandService: slashCommandService
        )

        // 设置 ConversationViewModel 的 messageSenderViewModel 引用
        self.conversationViewModel.messageSenderViewModel = self.messageSenderViewModel

        // 恢复上次选择的会话（在应用启动时只执行一次）
        // 注意：这里不加载 modelContext，因为初始化时可能还没有准备好
        // 实际的选择恢复会在 ConversationListView 出现时检查
        self.conversationViewModel.restoreSelectedConversation(modelContext: nil)

        // 初始化对话轮次 ViewModel
        let conversationTurnViewModel = ConversationTurnViewModel(
            llmService: llmService,
            toolService: toolService,
            promptService: promptService
        )

        // 初始化 AgentProvider（先创建，再注入到其他依赖中）
        self.agentProvider = AgentProvider(
            promptService: promptService,
            registry: ProviderRegistry(),
            toolService: toolService,
            toolsViewModel: toolsViewModel,
            chatHistoryService: chatHistoryService,
            messageViewModel: messageViewModel,
            conversationViewModel: conversationViewModel,
            messageSenderViewModel: self.messageSenderViewModel,
            projectViewModel: projectViewModel,
            conversationTurnViewModel: conversationTurnViewModel,
            slashCommandService: slashCommandService
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
            .environmentObject(toolsViewModel)
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
