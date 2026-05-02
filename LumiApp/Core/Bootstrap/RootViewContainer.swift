import Combine
import Foundation
import MagicKit
import SwiftData
import os

/// RootView 容器：管理所有服务和 ViewModel 的单例实例。
///
/// ## 架构原则
/// - 内核只管理通用服务
/// - 插件内部服务由插件自己管理
/// - 内核不知道具体插件的内部实现
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
    let messageRendererVM: MessageRendererVM
    let mystiqueThemeManager: ThemeManager
    let projectVM: ProjectVM
    let layoutVM: LayoutVM
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
    let gitVM: GitVM
    let agentSessionConfig: LLMVM
    let captureThinkingContent: Bool

    // MARK: - Editor

    let editorVM: EditorVM

    // MARK: - 初始化

    private init() {
        // 初始化 SwiftData 容器
        self.modelContainer = AppConfig.getContainer()

        // ========================================
        // 基础服务层（无依赖或依赖最少）
        // ========================================

        // 初始化上下文服务
        self.contextService = ContextService()

        // 初始化插件 VM
        self.pluginVM = PluginVM.shared

        // 初始化供应商注册表（从插件中收集 LLM Provider）
        let providerRegistry = LLMProviderRegistry()
        pluginVM.registerLLMProviders(to: providerRegistry)
        let registeredProviderIDs = providerRegistry.providerTypes.map { $0.id }

        // 初始化 LLM 服务
        self.llmService = LLMService(registry: providerRegistry)

        // 初始化提示词服务
        self.promptService = PromptService(contextService: contextService)

        // 初始化 Slash 命令服务
        self.slashCommandService = SlashCommandService()

        // 初始化工具服务
        self.toolService = ToolService(llmService: llmService)

        self.conversationTurnServices = ConversationTurnServices(
            promptService: promptService,
            toolService: toolService
        )

        // 供应商注册表
        self.providerRegistry = providerRegistry

        // ========================================
        // 基础 ViewModel
        // ========================================

        self.appProvider = GlobalVM()
        self.messageRendererVM = MessageRendererVM.shared
        self.mystiqueThemeManager = appProvider.themeManager
        self.projectVM = Lumi.ProjectVM(
            contextService: contextService,
            llmService: llmService
        )
        self.layoutVM = LayoutVM()

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

        self.gitVM = GitVM()
        self.agentSessionConfig = LLMVM(llmService: llmService)

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

        // ========================================
        // 编辑器
        // ========================================

        // 创建编辑器扩展注册中心
        let editorExtensionRegistry = EditorExtensionRegistry()

        // 让所有已启用的插件自行注册 editor 扩展
        // （替代通过 providesEditorExtensions 过滤的方案，避免 Swift 6 Actor 动态派发问题）
        let localPluginVM = pluginVM
        let pluginsToRegister = localPluginVM.plugins.filter { localPluginVM.isPluginEnabled($0) }
        for plugin in pluginsToRegister {
            plugin.registerEditorExtensions(into: editorExtensionRegistry)
        }
        // 将实际注册了的插件记录到 registry
        editorExtensionRegistry.recordInstalledPlugins(pluginsToRegister)
        
        os.Logger(subsystem: "com.coffic.lumi", category: "root").info("🔌 RootViewContainer: 插件自注册完成，installedPlugins=\(editorExtensionRegistry.installedPlugins.count)")

        self.editorVM = EditorVM(service: EditorService(editorExtensionRegistry: editorExtensionRegistry))

        // 将 registry 注入到 EditorSettingsState，使其 settingsSuggestions 和 reinstallEditorPlugins 可用
        EditorSettingsState.shared.configureRegistry(editorExtensionRegistry)

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
