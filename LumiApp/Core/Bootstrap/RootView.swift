import SwiftData
import SwiftUI

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
///
/// ## 单例模式
///
/// `RootView` 使用单例模式确保所有服务和 ViewModel 只被创建一次。
/// 通过 `RootViewContainer` 共享同一个实例，避免内存浪费。
///
/// ## 使用方式
///
/// ```swift
/// // 主窗口和设置窗口都使用同一个 RootView 实例
/// ContentLayout()
///     .inRootView()
///
/// SettingView()
///     .inRootView()
/// ```
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// 共享的容器实例
    @StateObject private var container = RootViewContainer.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(container.appProvider)
            .environmentObject(container.agentProvider)
            .environmentObject(container.projectViewModel)
            .environmentObject(PluginProvider.shared)
            .environmentObject(container.conversationViewModel)
            .environmentObject(container.messageViewModel)
            .environmentObject(container.messageSenderViewModel)
            .environmentObject(container.commandSuggestionViewModel)
            .environmentObject(container.toolsViewModel)
            .environmentObject(container.providerRegistry)
            .environmentObject(MystiqueThemeManager())
            .modelContainer(container.modelContainer)
    }
}

/// RootView 容器
/// 管理所有服务和 ViewModel 的单例实例
@MainActor
final class RootViewContainer: ObservableObject {
    /// 共享实例
    static let shared = RootViewContainer()

    // MARK: - 服务

    let modelContainer: ModelContainer
    let contextService: ContextService
    let llmService: LLMService
    let promptService: PromptService
    let slashCommandService: SlashCommandService
    let toolService: ToolService
    let providerRegistry: ProviderRegistry

    // MARK: - ViewModel

    let toolsViewModel: ToolsViewModel
    let appProvider: GlobalProvider
    let projectViewModel: ProjectViewModel
    let commandSuggestionViewModel: CommandSuggestionViewModel
    let messageViewModel: MessageViewModel
    let conversationViewModel: ConversationViewModel
    let messageSenderViewModel: MessageSenderViewModel
    let agentProvider: AgentProvider

    // MARK: - 初始化

    private init() {
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

        // 初始化供应商注册表
        self.providerRegistry = ProviderRegistry()

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

        // 创建 ConversationViewModel
        self.conversationViewModel = ConversationViewModel(
            chatHistoryService: chatHistoryService,
            llmService: llmService,
            promptService: promptService
        )

        // 创建 MessageSenderViewModel
        self.messageSenderViewModel = MessageSenderViewModel()

        // 初始化工具执行服务
        let toolExecutionService = ToolExecutionService(toolService: toolService)

        // 初始化对话轮次 ViewModel
        let conversationTurnViewModel = ConversationTurnViewModel(
            llmService: llmService,
            toolExecutionService: toolExecutionService,
            promptService: promptService
        )

        // 初始化 AgentProvider
        self.agentProvider = AgentProvider(
            promptService: promptService,
            registry: providerRegistry,
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
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Returns: 包装在 RootView 中的视图
    func inRootView() -> some View {
        RootView(content: { self })
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
