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
    let chatHistoryService: ChatHistoryService
    let conversationTurnServices: ConversationTurnServices
    let toolExecutionService: ToolExecutionService

    // MARK: - ViewModel

    let appProvider: GlobalVM
    let pluginVM: PluginVM
    let mystiqueThemeManager: MystiqueThemeManager
    let ProjectVM: Lumi.ProjectVM
    let commandSuggestionViewModel: CommandSuggestionVM
    let depthWarningViewModel: DepthWarningVM
    let permissionRequestViewModel: PermissionRequestVM
    let thinkingStateViewModel: ThinkingStateVM
    let taskCancellationVM: TaskCancellationVM
    let messageViewModel: MessagePendingVM
    let conversationVM: ConversationVM
    let messageQueueVM: MessageQueueVM
    let agentAttachmentsVM: AttachmentsVM
    let inputQueueVM: InputQueueVM
    let permissionHandlingVM: PermissionHandlingVM
    let conversationCreationVM: ConversationCreationVM
    let chatTimelineViewModel: ChatTimelineViewModel
    /// `RootView+Send` 等发送链路：按会话写入 `role == .status` 的瞬时状态消息（不落库）。
    let conversationSendStatusVM: ConversationSendStatusVM
    let projectContextRequestVM: ProjectContextRequestVM

    // MARK: - 对话轮次相关

    let conversationRuntimeStore: ConversationRuntimeStore
    let agentSessionConfig: AgentSessionConfig
    let captureThinkingContent: Bool
    let conversationTurnEvents: AsyncStream<ConversationTurnEvent>
    let conversationTurnEventContinuation: AsyncStream<ConversationTurnEvent>.Continuation
    var conversationTurnPipeline: ConversationTurnPipeline?
    var conversationTurnPluginsDidLoadObserver: NSObjectProtocol?
    var conversationTurnTaskPipelineByConversation: [UUID: Task<Void, Never>] = [:]
    var conversationTurnTaskGenerationByConversation: [UUID: Int] = [:]

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
        self.permissionRequestViewModel = PermissionRequestVM()
        self.thinkingStateViewModel = ThinkingStateVM()
        self.taskCancellationVM = TaskCancellationVM()

        // ========================================
        // 消息相关 VM
        // ========================================

        self.messageViewModel = MessagePendingVM()

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
            conversationVM: conversationVM,
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

        self.conversationCreationVM = ConversationCreationVM()

        self.projectContextRequestVM = ProjectContextRequestVM()

        // ========================================
        // 时间线
        // ========================================

        self.chatTimelineViewModel = ChatTimelineViewModel(
            runtimeStore: conversationRuntimeStore,
            chatHistoryService: chatHistoryService,
            conversationVM: conversationVM
        )

        self.conversationSendStatusVM = ConversationSendStatusVM()

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
