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
    let providerRegistry: ProviderRegistry

    // MARK: - ViewModel

    let appProvider: GlobalVM
    /// 与 `PluginVM.shared` 同一实例，便于经容器统一注入环境。
    let pluginVM: PluginVM
    /// 与 `appProvider.themeManager` 同一实例，避免 RootView 每次 `body` 新建主题管理器。
    let mystiqueThemeManager: MystiqueThemeManager
    let ProjectVM: Lumi.ProjectVM
    let commandSuggestionViewModel: CommandSuggestionVM

    // MARK: - 聊天历史服务

    let chatHistoryService: ChatHistoryService

    // MARK: - UI 状态 VM

    let depthWarningViewModel: DepthWarningVM
    let processingStateViewModel: ProcessingStateVM
    let permissionRequestViewModel: PermissionRequestVM
    let thinkingStateViewModel: ThinkingStateVM
    let agentTaskCancellationVM: TaskCancellationVM

    // MARK: - 消息相关 VM

    let messageViewModel: MessagePendingVM
    let ConversationVM: Lumi.ConversationVM
    let MessageSenderVM: Lumi.MessageQueueVM

    // MARK: - 输入与附件

    let agentAttachmentsVM: AttachmentsVM
    let inputQueueVM: InputQueueVM

    // MARK: - 对话轮次相关

    let conversationTurnServices: ConversationTurnServices
    let conversationRuntimeStore: ConversationRuntimeStore
    let agentSessionConfig: AgentSessionConfig
    let toolExecutionService: ToolExecutionService
    let captureThinkingContent: Bool
    let conversationTurnEvents: AsyncStream<ConversationTurnEvent>
    let conversationTurnEventContinuation: AsyncStream<ConversationTurnEvent>.Continuation
    var conversationTurnPipeline: ConversationTurnPipeline?
    var conversationTurnPluginsDidLoadObserver: NSObjectProtocol?
    var conversationTurnTaskPipelineByConversation: [UUID: Task<Void, Never>] = [:]
    var conversationTurnTaskGenerationByConversation: [UUID: Int] = [:]

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

        self.conversationTurnServices = ConversationTurnServices(
            promptService: promptService,
            toolService: toolService
        )

        // 复用 LLMService 中的供应商注册表（已通过插件完成注册）
        self.providerRegistry = llmService.providerRegistry

        // ========================================
        // 基础 ViewModel
        // ========================================

        self.appProvider = GlobalVM()
        self.pluginVM = PluginVM.shared
        self.mystiqueThemeManager = appProvider.themeManager
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
        self.agentTaskCancellationVM = TaskCancellationVM()

        // ========================================
        // 消息相关 VM
        // ========================================

        self.messageViewModel = MessagePendingVM()

        self.ConversationVM = Lumi.ConversationVM(
            chatHistoryService: chatHistoryService,
            llmService: llmService,
            promptService: promptService
        )

        self.MessageSenderVM = Lumi.MessageQueueVM()

        // ========================================
        // 输入与附件
        // ========================================

        self.agentAttachmentsVM = AttachmentsVM()
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

        self.conversationRuntimeStore = ConversationRuntimeStore()

        self.agentSessionConfig = AgentSessionConfig(
            projectVM: ProjectVM,
            registry: providerRegistry,
            chatHistoryService: chatHistoryService
        )

        self.toolExecutionService = ToolExecutionService(toolService: toolService)
        self.captureThinkingContent = true
        var continuation: AsyncStream<ConversationTurnEvent>.Continuation!
        self.conversationTurnEvents = AsyncStream { continuation = $0 }
        self.conversationTurnEventContinuation = continuation

        // ========================================
        // 权限与对话创建
        // ========================================

        self.permissionHandlingVM = PermissionHandlingVM(
            runtimeStore: conversationRuntimeStore,
            conversationVM: ConversationVM,
            permissionRequestViewModel: permissionRequestViewModel,
            emitPermissionDecision: { [conversationTurnEventContinuation] allowed, request, conversationId in
                conversationTurnEventContinuation.yield(
                    .permissionDecision(
                        allowed: allowed,
                        request: request,
                        conversationId: conversationId
                    )
                )
            }
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
            runtimeStore: conversationRuntimeStore,
            chatHistoryService: chatHistoryService,
            conversationVM: ConversationVM
        )


        MessageSenderVM.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        agentTaskCancellationVM.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
