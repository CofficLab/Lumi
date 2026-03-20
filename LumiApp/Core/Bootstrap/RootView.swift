import Combine
import Foundation
import MagicAlert
import MagicKit
import SwiftData
import SwiftUI

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
///
/// ## 架构说明
///
/// 所有服务和 ViewModel 均为全局单例，通过 `RootViewContainer.shared` 管理。
/// 多窗口场景下，所有窗口共享同一份状态和数据。
///
/// ## 使用方式
///
/// ```swift
/// ContentLayout()
///     .inRootView()
/// ```
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// 全局服务容器（单例）
    @StateObject private var container = RootViewContainer.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .withMagicToast()
            // 全局服务（所有窗口共享）
            .environmentObject(container.appProvider)
            .environmentObject(container.ProjectVM)
            .environmentObject(container.providerRegistry)
            .environmentObject(PluginVM.shared)
            // ViewModel（全局共享）
            .environmentObject(container.windowAgentCommands)
            .environmentObject(container.conversationRuntimeStore)
            .environmentObject(container.agentStreamingRender)
            .environmentObject(container.agentSessionConfig)
            .environmentObject(container.ConversationVM)
            .environmentObject(container.messageViewModel)
            .environmentObject(container.MessageSenderVM)
            .environmentObject(container.agentAttachmentsVM)
            .environmentObject(container.inputQueueVM)
            .environmentObject(container.permissionHandlingVM)
            .environmentObject(container.conversationCreationVM)
            .environmentObject(container.commandSuggestionViewModel)
            .environmentObject(container.depthWarningViewModel)
            .environmentObject(container.processingStateViewModel)
            .environmentObject(container.permissionRequestViewModel)
            .environmentObject(container.thinkingStateViewModel)
            .environmentObject(container.chatTimelineViewModel)
            .environmentObject(container.projectContextRequestVM)
            .environmentObject(MystiqueThemeManager())
            .modelContainer(container.modelContainer)
            .onAppear {
                PreferencesLoadHandler.handle(projectVM: container.ProjectVM, slashCommandService: container.slashCommandService)
                onInitialConversationLoaded()
            }
            .onChange(of: container.MessageSenderVM.pendingMessages.count) { oldCount, newCount in
                onSenderPendingMessagesChanged()
            }
            .onChange(of: container.depthWarningViewModel.depthWarning, onDepthWarningStateChanged)
            .onChange(of: container.projectContextRequestVM.request, onProjectContextRequestChanged)
            .onChange(of: container.ConversationVM.selectedConversationId, onConversationSelectionChanged)
            .task(id: ObjectIdentifier(container)) {
                await container.windowAgentCommands.makeConversationTurnPipelineHandler().run()
            }
    }
}

/// RootView 容器
/// 管理所有服务和 ViewModel 的单例实例
@MainActor
final class RootViewContainer: ObservableObject {
    /// 共享实例
    static let shared = RootViewContainer()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 服务

    let modelContainer: ModelContainer
    let contextService: ContextService
    let llmService: LLMService
    let promptService: PromptService
    let slashCommandService: SlashCommandService
    let toolService: ToolService
    let providerRegistry: ProviderRegistry

    // MARK: - ViewModel

    let appProvider: GlobalVM
    let ProjectVM: Lumi.ProjectVM
    let commandSuggestionViewModel: CommandSuggestionVM

    // MARK: - 聊天历史服务

    let chatHistoryService: ChatHistoryService

    // MARK: - UI 状态 VM

    let depthWarningViewModel: DepthWarningVM
    let processingStateViewModel: ProcessingStateVM
    let permissionRequestViewModel: PermissionRequestVM
    let thinkingStateViewModel: ThinkingStateVM

    // MARK: - 消息相关 VM

    let messageViewModel: MessagePendingVM
    let ConversationVM: Lumi.ConversationVM
    let MessageSenderVM: Lumi.MessageQueueVM

    // MARK: - 输入与附件

    let agentAttachmentsVM: AgentAttachmentsVM
    let inputQueueVM: InputQueueVM

    // MARK: - 对话轮次相关

    let conversationTurnViewModel: ConversationTurnVM
    let conversationRuntimeStore: ConversationRuntimeStore
    let agentStreamingRender: AgentStreamingRender
    let agentSessionConfig: AgentSessionConfig
    let windowAgentCommands: WindowAgentCommands

    // MARK: - 权限与对话创建

    let permissionHandlingVM: PermissionHandlingVM
    let conversationCreationVM: ConversationCreationVM
    let projectContextRequestVM: ProjectContextRequestVM

    // MARK: - 时间线

    let chatTimelineViewModel: ChatTimelineViewModel

    // MARK: - 初始化

    private init() {
        // 初始化 SwiftData 容器
        self.modelContainer = AppConfig.getContainer()

        // ========================================
        // 基础服务层（无依赖或依赖最少）
        // ========================================

        // 初始化上下文服务
        self.contextService = ContextService()

        // 初始化 LLM 服务
        self.llmService = LLMService()

        // 初始化提示词服务（依赖 ContextService）
        self.promptService = PromptService(contextService: contextService)

        // 初始化 Slash 命令服务
        self.slashCommandService = SlashCommandService()

        // 初始化工具服务
        self.toolService = ToolService(llmService: llmService)

        // 复用 LLMService 中的供应商注册表（已通过插件完成注册）
        self.providerRegistry = llmService.providerRegistry

        // ========================================
        // 基础 ViewModel
        // ========================================

        self.appProvider = GlobalVM()
        self.ProjectVM = Lumi.ProjectVM(
            contextService: contextService,
            providerRegistry: providerRegistry
        )

        // ========================================
        // 聊天历史服务
        // ========================================

        self.chatHistoryService = ChatHistoryService(
            llmService: llmService,
            modelContainer: modelContainer,
            reason: "RootViewContainer"
        )

        // ========================================
        // UI 状态 VM
        // ========================================

        self.depthWarningViewModel = DepthWarningVM()
        self.processingStateViewModel = ProcessingStateVM()
        self.permissionRequestViewModel = PermissionRequestVM()
        self.thinkingStateViewModel = ThinkingStateVM()

        // ========================================
        // 消息相关 VM
        // ========================================

        self.messageViewModel = MessagePendingVM(chatHistoryService: chatHistoryService)

        self.ConversationVM = Lumi.ConversationVM(
            chatHistoryService: chatHistoryService,
            llmService: llmService,
            promptService: promptService
        )

        self.MessageSenderVM = Lumi.MessageQueueVM()

        // ========================================
        // 输入与附件
        // ========================================

        self.agentAttachmentsVM = AgentAttachmentsVM()
        self.inputQueueVM = InputQueueVM(
            conversationVM: ConversationVM,
            messageSenderVM: MessageSenderVM,
            attachmentsVM: agentAttachmentsVM
        )

        // ========================================
        // 命令建议
        // ========================================

        self.commandSuggestionViewModel = CommandSuggestionVM(slashCommandService: slashCommandService)

        // ========================================
        // 对话轮次相关
        // ========================================

        let toolExecutionService = ToolExecutionService(toolService: toolService)

        self.conversationTurnViewModel = ConversationTurnVM(
            llmService: llmService,
            toolExecutionService: toolExecutionService,
            promptService: promptService
        )

        self.conversationRuntimeStore = ConversationRuntimeStore()

        self.agentStreamingRender = AgentStreamingRender(
            runtimeStore: conversationRuntimeStore,
            conversationVM: ConversationVM
        )

        self.agentSessionConfig = AgentSessionConfig(
            projectVM: ProjectVM,
            registry: providerRegistry,
            chatHistoryService: chatHistoryService
        )

        // ========================================
        // UI Handler
        // ========================================

        let agentUIHandler = DefaultAgentUIHandler(
            conversationVM: ConversationVM,
            processingStateViewModel: processingStateViewModel,
            permissionRequestViewModel: permissionRequestViewModel,
            thinkingStateViewModel: thinkingStateViewModel,
            depthWarningViewModel: depthWarningViewModel
        )

        // ========================================
        // WindowAgentCommands
        // ========================================

        self.windowAgentCommands = WindowAgentCommands(
            runtimeStore: conversationRuntimeStore,
            streamingRender: agentStreamingRender,
            sessionConfig: agentSessionConfig,
            promptService: promptService,
            registry: providerRegistry,
            toolService: toolService,
            chatHistoryService: chatHistoryService,
            messageViewModel: messageViewModel,
            ConversationVM: ConversationVM,
            MessageSenderVM: MessageSenderVM,
            projectVM: ProjectVM,
            conversationTurnViewModel: conversationTurnViewModel,
            slashCommandService: slashCommandService,
            uiHandler: agentUIHandler
        )

        // ========================================
        // 权限与对话创建
        // ========================================

        self.permissionHandlingVM = PermissionHandlingVM(
            runtimeStore: conversationRuntimeStore,
            conversationVM: ConversationVM,
            conversationTurnViewModel: conversationTurnViewModel,
            messageViewModel: messageViewModel,
            projectVM: ProjectVM,
            uiHandler: agentUIHandler
        )

        self.conversationCreationVM = ConversationCreationVM(
            promptService: promptService,
            chatHistoryService: chatHistoryService,
            messageSenderVM: MessageSenderVM,
            conversationVM: ConversationVM,
            projectVM: ProjectVM
        )

        self.projectContextRequestVM = ProjectContextRequestVM()

        // ========================================
        // 时间线
        // ========================================

        self.chatTimelineViewModel = ChatTimelineViewModel(
            streamingRender: agentStreamingRender,
            windowAgentCommands: windowAgentCommands,
            conversationVM: ConversationVM
        )

        // `MessageSenderVM` 嵌套在容器内且非 @Published；若不转发 objectWillChange，RootView 不会因队列变化重绘，
        // `.onChange(of: MessageSenderVM.pendingMessages.count)` 也不会触发。
        MessageSenderVM.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Event Handling

extension RootView {
    func onSenderPendingMessagesChanged() {
        SendMessageHandler.handle(
            vm: container.MessageSenderVM,
            messageViewModel: container.messageViewModel,
            conversationVM: container.ConversationVM,
            runtimeStore: container.conversationRuntimeStore,
            sessionConfig: container.agentSessionConfig,
            projectVM: container.ProjectVM,
            windowAgentCommands: container.windowAgentCommands,
            slashCommandService: container.slashCommandService,
            enqueueTurnProcessing: { [weak commands = container.windowAgentCommands] conversationId, depth in
                commands?.enqueueTurnProcessing(conversationId: conversationId, depth: depth)
            }
        )
    }

    func onDepthWarningStateChanged() {
        DepthWarningStateHandler.handle()
    }

    func onProjectContextRequestChanged() {
        ProjectContextRequestHandler.handle(
            request: container.projectContextRequestVM.request,
            container: container
        )
    }

    func onInitialConversationLoaded() {
        guard let conversationId = container.ConversationVM.selectedConversationId else { return }

        let handler = ConversationChangedHandler(
            windowAgentCommands: container.windowAgentCommands,
            conversationVM: container.ConversationVM,
            messageSenderVM: container.MessageSenderVM,
            projectVM: container.ProjectVM,
            promptService: container.promptService,
            slashCommandService: container.slashCommandService,
            messageViewModel: container.messageViewModel,
            processingStateViewModel: container.processingStateViewModel,
            thinkingStateViewModel: container.thinkingStateViewModel,
            permissionRequestViewModel: container.permissionRequestViewModel,
            depthWarningViewModel: container.depthWarningViewModel
        )

        Task { await handler.handle(conversationId: conversationId, applyProjectContext: false) }
    }

    func onConversationSelectionChanged() {
        guard let conversationId = container.ConversationVM.selectedConversationId else { return }

        let handler = ConversationChangedHandler(
            windowAgentCommands: container.windowAgentCommands,
            conversationVM: container.ConversationVM,
            messageSenderVM: container.MessageSenderVM,
            projectVM: container.ProjectVM,
            promptService: container.promptService,
            slashCommandService: container.slashCommandService,
            messageViewModel: container.messageViewModel,
            processingStateViewModel: container.processingStateViewModel,
            thinkingStateViewModel: container.thinkingStateViewModel,
            permissionRequestViewModel: container.permissionRequestViewModel,
            depthWarningViewModel: container.depthWarningViewModel
        )

        Task { await handler.handle(conversationId: conversationId, applyProjectContext: true) }
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
