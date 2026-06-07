import CodeEditTextView
import EditorService
import Foundation
import SwiftData
import os

/// RootView 容器：管理全局共享的服务和 ViewModel 的单例实例。
///
/// ## 架构原则
/// - **全局共享层**：Service 和应用级 VM 留在此容器（如 AppPluginVM、AppThemeVM）
/// - **窗口作用域层**：窗口级 VM 由 `WindowContainer` 持有（如 WindowConversationVM、WindowProjectVM）
///
/// ## VM 分类
///
/// **全局共享（留在 RootContainer）：**
/// AppPluginVM, AppThemeVM, AppLLMVM, AppChatHistoryVM, AppGitVM, AppIdleTimeVM, AppMessageRendererVM
///
/// **窗口作用域（在 WindowContainer 中）：**
/// WindowEditorVM, WindowConversationVM, WindowProjectVM, WindowLayoutVM, WindowMessageQueueVM,
/// WindowInputQueueVM, WindowAttachmentsVM, WindowPermissionRequestVM, WindowPermissionHandlingVM,
/// WindowConversationStatusVM, WindowTaskCancellationVM, WindowCommandSuggestionVM,
/// WindowProjectContextRequestVM
@MainActor
final class RootContainer: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔌"
    nonisolated static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "root")
    
    /// 共享实例
    static let shared = RootContainer()
    
    // MARK: - 服务（全局共享）
    
    let modelContainer: ModelContainer
    let contextService: ContextService
    let llmService: LLMService
    let promptService: PromptService
    let slashCommandService: SlashCommandService
    let toolService: ToolService
    let providerRegistry: LLMProviderRegistry
    let chatHistoryService: ChatHistoryService
    let conversationService: ConversationService
    let messageService: MessageService
    let performanceService: PerformanceService
    let conversationTurnServices: AppConversationTurnVM
    
    // MARK: - 全局 ViewModel（应用级，所有窗口共享）
    
    let windowManagerVM: AppWindowManagerVM
    let pluginVM: AppPluginVM
    let messageRendererVM: AppMessageRendererVM
    let themeVM: AppThemeVM
    let chatHistoryVM: AppChatHistoryVM
    let recentProjectsVM: AppProjectsVM
    let gitVM: AppGitVM
    let agentSessionConfig: AppLLMVM
    let captureThinkingContent: Bool
    let idleTimeVM: AppIdleTimeVM
    
    // MARK: - 窗口级 ViewModel 兼容属性（仅保留仍在使用的项目）
    //
    // ⚠️ 新代码请勿使用这些属性，应通过 WindowContainer 直接访问。
    
    /// 活跃窗口的 WindowConversationVM（过渡兼容，新代码用 WindowContainer）
    var conversationVM: WindowConversationVM {
        windowManagerVM.activeWindowContainer?.conversationVM ?? _fallbackWindowConversationVM
    }
    
    /// 活跃窗口的 WindowLayoutVM（过渡兼容，新代码用 WindowContainer）
    var layoutVM: WindowLayoutVM {
        windowManagerVM.activeWindowContainer?.layoutVM ?? _fallbackWindowLayoutVM
    }
    
    // Fallback 实例（仅 conversationVM 需要兜底；layoutVM 和 editorVM 使用动态创建）
    private let _fallbackWindowConversationVM: WindowConversationVM
    private let _fallbackWindowLayoutVM: WindowLayoutVM
    
    // MARK: - 初始化
    
    private init() {
        // 初始化 SwiftData 容器
        self.modelContainer = AppConfig.getContainer()
        
        // ========================================
        // 基础服务层（无依赖或依赖最少）
        // ========================================
        
        self.contextService = ContextService()
        self.pluginVM = AppPluginVM.shared
        
        let providerRegistry = LLMProviderRegistry()
        pluginVM.registerLLMProviders(to: providerRegistry)
        
        self.llmService = LLMService(registry: providerRegistry)
        self.promptService = PromptService()
        self.slashCommandService = SlashCommandService()
        self.toolService = ToolService(llmService: llmService)
        
        self.conversationTurnServices = AppConversationTurnVM(
            promptService: promptService,
            toolService: toolService
        )
        
        self.providerRegistry = providerRegistry
        
        // ========================================
        // 全局 ViewModel
        // ========================================
        
        self.windowManagerVM = AppWindowManagerVM()
        self.messageRendererVM = AppMessageRendererVM.shared
        self.themeVM = AppThemeVM()
        
        // ========================================
        // 聊天历史服务
        // ========================================
        
        self.conversationService = ConversationService(
            modelContainer: modelContainer,
            reason: "RootViewContainer"
        )

        self.messageService = MessageService(
            conversationService: conversationService,
            reason: "RootViewContainer"
        )

        self.chatHistoryService = ChatHistoryService(
            messageService: messageService,
            conversationService: conversationService,
            reason: "RootViewContainer"
        )

        self.performanceService = PerformanceService(
            modelContainer: modelContainer,
            reason: "RootViewContainer"
        )

        self.chatHistoryVM = AppChatHistoryVM(
            messageService: messageService,
            chatHistoryService: chatHistoryService,
            conversationService: conversationService,
            performanceService: performanceService
        )
        self.recentProjectsVM = AppProjectsVM()
        
        // ========================================
        // Agent 配置
        // ========================================
        
        self.gitVM = AppGitVM()
        self.agentSessionConfig = AppLLMVM(llmService: llmService)
        toolService.llmVM = agentSessionConfig
        toolService.recentProjectsVM = recentProjectsVM
        self.captureThinkingContent = true
        
        // ========================================
        // Fallback 窗口级 VM（仅 conversationVM 需要兜底）
        // ========================================
        
        _fallbackWindowConversationVM = WindowConversationVM(
            chatHistoryService: chatHistoryService,
            conversationService: conversationService,
            promptService: promptService,
            agentSessionConfig: agentSessionConfig
        )
        _fallbackWindowLayoutVM = WindowLayoutVM()
        
        // ========================================
        // 编辑器（全局配置 + 窗口级 VM 工厂）
        // ========================================
        
        // 全局编辑器配置（只执行一次）
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
        
        EditorSettingsLifecycle.hostPersistenceRootURL = { AppConfig.getDBFolderURL() }
        EditorSettingsLifecycle.editorThemeIDForAppThemeID = { AppThemeVM.editorThemeID(for: $0) }
        EditorSettingsLifecycle.loadEditorRecentCommandIDs = { AppSettingStore.loadEditorRecentCommandIDs() }
        EditorSettingsLifecycle.saveEditorRecentCommandIDs = { AppSettingStore.saveEditorRecentCommandIDs($0) }
        EditorSettingsLifecycle.loadEditorCommandUsageCounts = { AppSettingStore.loadEditorCommandUsageCounts() }
        EditorSettingsLifecycle.saveEditorCommandUsageCounts = { AppSettingStore.saveEditorCommandUsageCounts($0) }
        EditorSettingsLifecycle.loadEditorCommandPaletteCategory = { AppSettingStore.loadEditorCommandPaletteCategory() }
        EditorSettingsLifecycle.saveEditorCommandPaletteCategory = { AppSettingStore.saveEditorCommandPaletteCategory($0) }
        EditorSettingsLifecycle.setEditorFeaturePluginEnabled = { pluginID, enabled in
            AppPluginSettingsVM.shared.setPluginEnabled(pluginID, enabled: enabled)
        }
        
        EditorSettingsLifecycle.registerEditorThemeContributors = { @MainActor registry in
            for plugin in AppPluginVM.shared.plugins {
                guard AppPluginVM.shared.isPluginEnabled(plugin),
                      plugin.pluginCategory == .theme else { continue }
                plugin.registerEditorExtensions(into: registry)
            }
        }
        
        // 初始化时创建一个编辑器实例，用于配置全局 EditorSettingsState
        let initialRegistry = Self.createEditorExtensionRegistry(for: pluginVM)
        EditorSettingsState.shared.configureRegistry(initialRegistry)
        
        EditorSettingsLifecycle.onReinstallPlugins = { registry in
            let plugins = AppPluginVM.shared.plugins.filter { AppPluginVM.shared.isPluginEnabled($0) }
            for plugin in plugins {
                plugin.registerEditorExtensions(into: registry)
            }
            let records = plugins.map { plugin -> EditorInstalledPluginRecord in
                return EditorInstalledPluginRecord(
                    id: plugin.pluginID,
                    displayName: plugin.pluginDisplayName,
                    description: plugin.pluginDescription,
                    order: plugin.pluginOrder,
                    isConfigurable: plugin.pluginIsConfigurable
                )
            }
            registry.recordInstalledPlugins(records)
        }
        
        EditorSettingsLifecycle.onQuickOpenSettingSelected = { searchQuery in
            AppSettingStore.savePendingEditorSettingsSearchQuery(searchQuery.isEmpty ? nil : searchQuery)
            AppSettingStore.saveSettingsSelection(type: "core", value: SettingTab.editor.rawValue)
            NotificationCenter.postOpenSettings()
        }
        
        // ========================================
        // 空闲时间
        // ========================================
        
        self.idleTimeVM = AppIdleTimeVM()
    }
    
    // MARK: - Editor VM Factory
    
    /// 创建编辑器扩展注册中心（每窗口独立）
    func createEditorExtensionRegistry() -> EditorExtensionRegistry {
        Self.createEditorExtensionRegistry(for: pluginVM)
    }
    
    /// 静态工厂方法，可在 init 期间安全调用
    private static func createEditorExtensionRegistry(for pluginVM: AppPluginVM) -> EditorExtensionRegistry {
        let registry = EditorExtensionRegistry()
        let pluginsToRegister = pluginVM.plugins.filter { pluginVM.isPluginEnabled($0) }
        for plugin in pluginsToRegister {
            plugin.registerEditorExtensions(into: registry)
        }
        let pluginRecords = pluginsToRegister.map { plugin -> EditorInstalledPluginRecord in
            return EditorInstalledPluginRecord(
                id: plugin.pluginID,
                displayName: plugin.pluginDisplayName,
                description: plugin.pluginDescription,
                order: plugin.pluginOrder,
                isConfigurable: plugin.pluginIsConfigurable
            )
        }
        registry.recordInstalledPlugins(pluginRecords)
        EditorSettingsLifecycle.registerEditorThemeContributors?(registry)
        return registry
    }
    
    /// 活跃窗口的 EditorVM（过渡兼容）
    var editorVM: WindowEditorVM {
        windowManagerVM.activeWindowContainer?.editorVM ?? WindowEditorVM(service: EditorService(editorExtensionRegistry: createEditorExtensionRegistry()))
    }
}
