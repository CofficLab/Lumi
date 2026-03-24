import Combine
import Foundation
import MagicKit
import SwiftData

/// RootView 容器：管理所有服务和 ViewModel 的单例实例。
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
    let providerRegistry: LLMProviderRegistry
    let chatHistoryService: ChatHistoryService
    let conversationTurnServices: ConversationTurnServices
    let toolExecutionService: ToolExecutionService

    // MARK: - ViewModel

    let appProvider: GlobalVM
    let pluginVM: PluginVM
    let mystiqueThemeManager: MystiqueThemeManager
    let projectVM: ProjectVM
    let chatHistoryVM: ChatHistoryVM
    let commandSuggestionVM: CommandSuggestionVM
    let permissionRequestVM: PermissionRequestVM
    let taskCancellationVM: TaskCancellationVM
    let messagePendingVM: MessagePendingVM
    let conversationVM: ConversationVM
    let messageQueueVM: MessageQueueVM
    let agentAttachmentsVM: AttachmentsVM
    let inputQueueVM: InputQueueVM
    let permissionHandlingVM: PermissionHandlingVM
    let conversationCreationVM: ConversationCreationVM
    let chatTimelineViewModel: ChatTimelineViewModel
    let conversationSendStatusVM: ConversationStatusVM
    let projectContextRequestVM: ProjectContextRequestVM

    let agentSessionConfig: AgentSessionVM
    let captureThinkingContent: Bool

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

        self.conversationTurnServices = ConversationTurnServices(
            promptService: promptService,
            toolService: toolService
        )

        // 复用 LLMService 中的供应商注册表（已通过插件完成注册）
        self.providerRegistry = llmService.registry

        // ========================================
        // 基础 ViewModel
        // ========================================

        self.appProvider = GlobalVM()
        self.pluginVM = PluginVM.shared
        self.mystiqueThemeManager = appProvider.themeManager
        self.projectVM = Lumi.ProjectVM(
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

        // 聊天历史 ViewModel
        self.chatHistoryVM = ChatHistoryVM(chatHistoryService: chatHistoryService)

        // ========================================
        // UI 状态 VM
        // ========================================

        self.permissionRequestVM = PermissionRequestVM()
        self.taskCancellationVM = TaskCancellationVM()

        // ========================================
        // 消息相关 VM
        // ========================================

        self.messagePendingVM = MessagePendingVM()

        self.conversationVM = Lumi.ConversationVM(
            chatHistoryService: chatHistoryService
        )

        self.messageQueueVM = Lumi.MessageQueueVM()

        // ========================================
        // 输入与附件
        // ========================================

        self.agentAttachmentsVM = AttachmentsVM()
        self.inputQueueVM = InputQueueVM()

        // ========================================
        // 命令建议
        // ========================================

        self.commandSuggestionVM = CommandSuggestionVM(slashCommandService: slashCommandService)

        // ========================================
        // Agent 配置
        // ========================================

        self.agentSessionConfig = AgentSessionVM(llmService: llmService)

        self.toolExecutionService = ToolExecutionService(toolService: toolService)
        self.captureThinkingContent = true

        // ========================================
        // 权限与对话创建
        // ========================================

        self.permissionHandlingVM = PermissionHandlingVM(
            permissionRequestViewModel: permissionRequestVM,
            chatHistoryService: chatHistoryService,
            toolExecutionService: toolExecutionService
        )

        self.conversationCreationVM = ConversationCreationVM()

        self.projectContextRequestVM = ProjectContextRequestVM()

        // ========================================
        // 时间线
        // ========================================

        self.chatTimelineViewModel = ChatTimelineViewModel(
            chatHistoryService: chatHistoryService,
            conversationVM: conversationVM
        )

        self.conversationSendStatusVM = ConversationStatusVM()

        messageQueueVM.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        inputQueueVM.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        taskCancellationVM.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        conversationCreationVM.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        conversationSendStatusVM.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}