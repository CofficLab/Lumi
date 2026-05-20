import CodeEditTextView
import EditorService
import Foundation
import MagicKit
import SwiftData
import os

/// RootView 容器：管理全局共享的服务和 ViewModel 的单例实例。
///
/// ## 架构原则
/// - **全局共享层**：Service 和应用级 VM 留在此容器（如 AppPluginVM、AppThemeVM）
/// - **窗口作用域层**：窗口级 VM 由 `WindowScope` 持有（如 WindowConversationVM、WindowProjectVM）
///
/// ## VM 分类
///
/// **全局共享（留在 RootContainer）：**
/// AppPluginVM, AppThemeVM, AppLLMVM, AppChatHistoryVM, AppGitVM, AppIdleTimeVM, AppMessageRendererVM
///
/// **窗口作用域（在 WindowScope 中）：**
/// WindowEditorVM, WindowConversationVM, WindowProjectVM, WindowLayoutVM, WindowMessagePendingVM, WindowMessageQueueVM,
/// WindowInputQueueVM, WindowAttachmentsVM, WindowPermissionRequestVM, WindowPermissionHandlingVM,
/// WindowConversationStatusVM, WindowConversationCreationVM, WindowTaskCancellationVM,
/// WindowCommandSuggestionVM, WindowProjectContextRequestVM, WindowChatTimelineViewModel
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
    let conversationTurnServices: AppConversationTurnServicesVM
    let toolExecutionService: ToolExecutionService
    
    // MARK: - 全局 ViewModel（应用级，所有窗口共享）
    
    let windowManagerVM: WindowManagerVM
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
    // ⚠️ 新代码请勿使用这些属性，应通过 WindowScope 直接访问。
    
    /// 活跃窗口的 WindowConversationVM（过渡兼容，新代码用 WindowScope）
    var conversationVM: WindowConversationVM {
        windowManagerVM.activeWindowScope?.conversationVM ?? _fallbackWindowConversationVM
    }
    
    /// 活跃窗口的 WindowLayoutVM（过渡兼容，新代码用 WindowScope）
    var layoutVM: WindowLayoutVM {
        windowManagerVM.activeWindowScope?.layoutVM ?? _fallbackWindowLayoutVM
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
        self.promptService = PromptService(contextService: contextService)
        self.slashCommandService = SlashCommandService()
        self.toolService = ToolService(llmService: llmService)
        
        self.conversationTurnServices = AppConversationTurnServicesVM(
            promptService: promptService,
            toolService: toolService
        )
        
        self.providerRegistry = providerRegistry
        
        // ========================================
        // 全局 ViewModel
        // ========================================
        
        self.windowManagerVM = WindowManagerVM()
        self.messageRendererVM = AppMessageRendererVM.shared
        self.themeVM = AppThemeVM()
        
        // ========================================
        // 聊天历史服务
        // ========================================
        
        self.chatHistoryService = ChatHistoryService(
            llmService: llmService,
            modelContainer: modelContainer,
            reason: "RootViewContainer"
        )
        
        self.chatHistoryVM = AppChatHistoryVM(chatHistoryService: chatHistoryService)
        self.recentProjectsVM = AppProjectsVM()
        
        // ========================================
        // Agent 配置
        // ========================================
        
        self.gitVM = AppGitVM()
        self.agentSessionConfig = AppLLMVM(llmService: llmService)
        toolService.llmVM = agentSessionConfig
        self.toolExecutionService = ToolExecutionService(toolService: toolService)
        self.captureThinkingContent = true
        
        // ========================================
        // Fallback 窗口级 VM（仅 conversationVM 需要兜底）
        // ========================================
        
        _fallbackWindowConversationVM = WindowConversationVM(chatHistoryService: chatHistoryService)
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
        
        EditorSettingsLifecycle.registerEditorThemeContributors = { registry in
            for contribution in AppPluginVM.shared.getThemeContributions() {
                if let c = contribution.editorThemeContributor as? any SuperEditorThemeContributor {
                    registry.registerThemeContributor(c)
                }
            }
        }
        
        EditorSettingsLifecycle.registerMultiCursorTextView = { textView, state in
            MultiCursorInputInstaller.shared.register(textView: textView, state: state)
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
            let t = type(of: plugin)
            return EditorInstalledPluginRecord(
                id: t.id,
                displayName: t.displayName,
                description: t.description,
                order: t.order,
                isConfigurable: t.isConfigurable
            )
        }
        registry.recordInstalledPlugins(pluginRecords)
        return registry
    }
    
    /// 活跃窗口的 EditorVM（过渡兼容）
    var editorVM: WindowEditorVM {
        windowManagerVM.activeWindowScope?.editorVM ?? WindowEditorVM(service: EditorService(editorExtensionRegistry: createEditorExtensionRegistry()))
    }
}
