import SwiftData
import SwiftUI

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
///
/// ## 多窗口支持
///
/// `RootView` 现在支持多窗口模式，每个窗口有自己独立的 ViewModel 实例。
/// 共享的服务层（如 LLMService、ModelContainer）仍然保持单例，
/// 但窗口级的 ViewModel（如 AgentProvider、MessageViewModel）是每个窗口独立的。
///
/// ## 使用方式
///
/// ```swift
/// // 主窗口和设置窗口都使用 RootView，每个窗口有独立的状态
/// ContentLayout()
///     .inRootView()
///
/// SettingView()
///     .inRootView()
/// ```
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// 共享的服务容器（单例）
    @StateObject private var container = RootViewContainer.shared

    /// 窗口级视图容器（每个窗口独立）
    @StateObject private var windowContainer: WindowViewContainer

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        // 创建窗口级容器，传入共享服务
        _windowContainer = StateObject(wrappedValue: WindowViewContainer(services: RootViewContainer.shared.services))
    }

    var body: some View {
        content
            // 共享的全局服务（所有窗口共享）
            .environmentObject(container.appProvider)
            .environmentObject(container.projectViewModel)
            .environmentObject(container.toolsViewModel)
            .environmentObject(container.providerRegistry)
            .environmentObject(PluginProvider.shared)
            // 窗口级 ViewModel（每个窗口独立）
            .environmentObject(windowContainer.agentProvider)
            .environmentObject(windowContainer.conversationViewModel)
            .environmentObject(windowContainer.messageViewModel)
            .environmentObject(windowContainer.messageSenderViewModel)
            .environmentObject(windowContainer.commandSuggestionViewModel)
            .environmentObject(windowContainer.depthWarningViewModel)
            .environmentObject(windowContainer.processingStateViewModel)
            .environmentObject(windowContainer.errorStateViewModel)
            .environmentObject(windowContainer.permissionRequestViewModel)
            .environmentObject(windowContainer.thinkingStateViewModel)
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

    /// 共享服务集合（用于创建窗口级 ViewModel）
    var services: Services {
        Services(
            modelContainer: modelContainer,
            contextService: contextService,
            llmService: llmService,
            promptService: promptService,
            slashCommandService: slashCommandService,
            toolService: toolService,
            providerRegistry: providerRegistry,
            toolsViewModel: toolsViewModel,
            appProvider: appProvider,
            projectViewModel: projectViewModel,
            commandSuggestionViewModel: commandSuggestionViewModel
        )
    }

    /// 服务集合结构体
    struct Services {
        let modelContainer: ModelContainer
        let contextService: ContextService
        let llmService: LLMService
        let promptService: PromptService
        let slashCommandService: SlashCommandService
        let toolService: ToolService
        let providerRegistry: ProviderRegistry
        let toolsViewModel: ToolsViewModel
        let appProvider: GlobalProvider
        let projectViewModel: ProjectViewModel
        let commandSuggestionViewModel: CommandSuggestionViewModel
    }

    // MARK: - ViewModel

    let toolsViewModel: ToolsViewModel
    let appProvider: GlobalProvider
    let projectViewModel: ProjectViewModel
    let commandSuggestionViewModel: CommandSuggestionViewModel
    let messageViewModel: MessageViewModel
    let conversationViewModel: ConversationViewModel
    let messageSenderViewModel: MessageSenderViewModel
    let agentProvider: AgentProvider
    let depthWarningViewModel: DepthWarningViewModel
    let processingStateViewModel: ProcessingStateViewModel
    let errorStateViewModel: ErrorStateViewModel
    let permissionRequestViewModel: PermissionRequestViewModel
    let thinkingStateViewModel: ThinkingStateViewModel
    let titleGenerationViewModel: TitleGenerationViewModel

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
        self.toolService = ToolService(llmService: llmService)

        // 初始化供应商注册表
        self.providerRegistry = ProviderRegistry()

        // ========================================
        // ViewModel 层
        // ========================================

        // 创建 Tools ViewModel
        self.toolsViewModel = ToolsViewModel(toolService: toolService)

        // 初始化状态 ViewModels
        self.depthWarningViewModel = DepthWarningViewModel()
        self.processingStateViewModel = ProcessingStateViewModel()
        self.errorStateViewModel = ErrorStateViewModel()
        self.permissionRequestViewModel = PermissionRequestViewModel()
        self.thinkingStateViewModel = ThinkingStateViewModel()
        self.titleGenerationViewModel = TitleGenerationViewModel()

        // 初始化聊天历史服务（依赖 LLMService）
        let chatHistoryService = ChatHistoryService(
            llmService: llmService,
            modelContainer: self.modelContainer,
            reason: "RootViewContainer"
        )

        // 初始化基础 ViewModel
        self.appProvider = GlobalProvider()
        self.projectViewModel = ProjectViewModel(contextService: contextService)
        self.commandSuggestionViewModel = CommandSuggestionViewModel(slashCommandService: slashCommandService)

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
            slashCommandService: slashCommandService,
            depthWarningViewModel: self.depthWarningViewModel,
            processingStateViewModel: self.processingStateViewModel,
            errorStateViewModel: self.errorStateViewModel,
            permissionRequestViewModel: self.permissionRequestViewModel,
            thinkingStateViewModel: self.thinkingStateViewModel,
            titleGenerationViewModel: self.titleGenerationViewModel
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
