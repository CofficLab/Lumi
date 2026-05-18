import CodeEditTextView
import EditorService
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
final class RootContainer: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔌"
    nonisolated static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "root")

    /// 共享实例
    static let shared = RootContainer()

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

    let pluginVM: PluginVM
    let messageRendererVM: MessageRendererVM
    let themeVM: ThemeVM
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
    let editorVM: EditorVM
    let idleTimeVM: IdleTimeVM

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

        self.messageRendererVM = MessageRendererVM.shared
        self.themeVM = ThemeVM()
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

        EditorHostEnvironment.configure(
            EditorHostEnvironment(
                logSubsystem: "com.coffic.lumi",
                localizationTable: "LumiEditor",
                storageDirectoryName: "LumiEditor",
                notifications: .init(
                    projectContextDidChange: Notification.Name("LumiEditorProjectContextDidChange"),
                    settingsDidChange: Notification.Name("LumiEditorSettingsDidChange"),
                    themeDidChange: Notification.Name("lumiThemeDidChange"),
                    toggleOpenEditorsPanel: Notification.Name("LumiEditorToggleOpenEditorsPanel"),
                    toggleOutlinePanel: Notification.Name("LumiEditorToggleOutlinePanel"),
                    showCommandPalette: Notification.Name("LumiEditorShowCommandPalette"),
                    triggerCompletion: Notification.Name("LumiEditorTriggerCompletion"),
                    triggerSignatureHelp: Notification.Name("LumiEditorTriggerSignatureHelp")
                )
            )
        )

        // 创建编辑器扩展注册中心
        let editorExtensionRegistry = EditorExtensionRegistry()

        // 让所有已启用的插件自行注册 editor 扩展
        let localPluginVM = pluginVM
        let pluginsToRegister = localPluginVM.plugins.filter { localPluginVM.isPluginEnabled($0) }
        for plugin in pluginsToRegister {
            plugin.registerEditorExtensions(into: editorExtensionRegistry)
        }
        // 将实际注册了的插件记录到 registry
        let pluginRecords = pluginsToRegister.map { plugin -> EditorInstalledPluginRecord in
            let t = type(of: plugin)
            return EditorInstalledPluginRecord(
                id: t.id,
                displayName: t.displayName,
                description: t.description,
                order: t.order,
                isConfigurable: t.isConfigurable
            )
        }
        editorExtensionRegistry.recordInstalledPlugins(pluginRecords)

        EditorSettingsLifecycle.registerEditorThemeContributors = { registry in
            for contribution in PluginVM.shared.getThemeContributions() {
                if let c = contribution.editorThemeContributor as? any SuperEditorThemeContributor {
                    registry.registerThemeContributor(c)
                }
            }
        }

        EditorSettingsLifecycle.registerMultiCursorTextView = { textView, state in
            MultiCursorInputInstaller.shared.register(textView: textView, state: state)
        }

        self.editorVM = EditorVM(service: EditorService(editorExtensionRegistry: editorExtensionRegistry))

        // 将 registry 注入到 EditorSettingsState，使其 settingsSuggestions 和 reinstallEditorPlugins 可用
        EditorSettingsState.shared.configureRegistry(editorExtensionRegistry)

        EditorSettingsLifecycle.onReinstallPlugins = { registry in
            let plugins = PluginVM.shared.plugins.filter { PluginVM.shared.isPluginEnabled($0) }
            for plugin in plugins {
                plugin.registerEditorExtensions(into: registry)
            }
            let records = plugins.map { plugin -> EditorInstalledPluginRecord in
                let t = type(of: plugin)
                return EditorInstalledPluginRecord(
                    id: t.id,
                    displayName: t.displayName,
                    description: t.description,
                    order: t.order,
                    isConfigurable: t.isConfigurable
                )
            }
            registry.recordInstalledPlugins(records)
        }

        EditorSettingsLifecycle.onQuickOpenSettingSelected = { searchQuery in
            AppSettingStore.saveSettingsSelection(type: "core", value: SettingTab.editor.rawValue)
            AppSettingStore.savePendingEditorSettingsSearchQuery(searchQuery)
            NotificationCenter.postOpenSettings()
        }

        // ========================================
        // 空闲时间
        // ========================================

        self.idleTimeVM = IdleTimeVM()
    }
}
