import LumiChatKit
import LumiCoreKit
import LumiUI
import SuperLogKit
import SwiftUI
import EditorService
import os

@MainActor
final class RootContainer: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.root-container")
    nonisolated static let emoji = "🗂️"
    nonisolated static let verbose = true

    static let shared = RootContainer()

    let lumiCoreService: LumiCoreService
    let pluginService: PluginService
    let toolService: ToolService
    let editorCoreService: EditorCoreService
    let chatCoreService: ChatCoreService
    let chatSectionCoordinator: ChatSectionCoordinator
    let lumiUIService: LumiUIService
    let menuBarService: MenuBarService

    private init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)开始初始化 RootContainer")
        }

        self.lumiCoreService = LumiCoreService()
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ LumiCoreService 初始化完成")
        }

        self.pluginService = PluginService()
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ PluginService 初始化完成")
        }

        self.toolService = ToolService()
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ ToolService 初始化完成")
        }

        self.editorCoreService = EditorCoreService(
            pluginService: pluginService,
            persistenceRootURL: { AppConfig.getDBFolderURL() },
            recentProjects: { [] }
        )
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ EditorCoreService 初始化完成")
        }

        self.chatCoreService = ChatCoreService(
            lumiCoreService: lumiCoreService,
            pluginService: pluginService,
            toolService: toolService
        )
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ ChatCoreService 初始化完成")
        }

        self.chatSectionCoordinator = ChatSectionCoordinator(
            chatService: chatCoreService.chatService,
            databaseDirectory: lumiCoreService.coreDatabaseDirectory
        )
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ ChatSectionCoordinator 初始化完成")
        }

        self.lumiUIService = LumiUIService(pluginService: pluginService)
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ LumiUIService 初始化完成")
        }

        self.menuBarService = MenuBarService(pluginService: pluginService)
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ MenuBarService 初始化完成")
        }

        // 注册核心服务到 LumiCore，供 makePluginContext 自动注入
        LumiCore.registerService(LumiCoreService.self, lumiCoreService)
        LumiCore.registerService((any LumiChatServicing).self, chatCoreService.chatService)
        LumiCore.registerService((any HistoryQueryService).self, chatCoreService.chatService)
        LumiCore.registerService(LumiEditorServicing.self, editorCoreService)
        LumiCore.registerService(ChatSectionCoordinator.self, chatSectionCoordinator)
        LumiCore.registerService(LumiBottomPanelLayoutPresenting.self, LumiCore.layoutState ?? LumiLayoutState())
        LumiCore.registerService(ToolService.self, toolService)
        LumiCore.registerService(LumiThemeServicing.self, lumiUIService)
        LumiCore.registerService((any LumiLLMProviderSettingsContributing).self, pluginService)

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ LumiCore 服务注册表初始化完成")
        }

        self.lumiUIService.onThemesDidChange = { [weak self] in
            self?.editorCoreService.syncAppSyntaxThemes()
        }
        LumiUIThemeRegistry.shared.onSystemAppearanceDidChange = { [weak self] in
            self?.editorCoreService.syncAppSyntaxThemes()
        }

        // 异步触发 UpdateController 的网络探测与延迟初始化，不阻塞主线程。
        // setupFeedURLIfNeeded 内部用 Task.detached 把网络请求放到后台线程，
        // 只有 Sparkle 必须在主线程的两步操作才会 hop 回 MainActor。
        UpdateController.shared.setupFeedURLIfNeeded()
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ UpdateController 启动完成")
        }

        // 布局状态由 LumiCore.layoutState 统一管理
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 布局状态已配置")
        }

        // 初始化插件启用状态跟踪
        self.pluginService.initializePluginStates()
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 插件状态初始化完成")
        }

        self.pluginService.onEnabledPluginsChanged = { [weak self] in
            guard let self else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件启用状态变化，刷新相关服务")
            }
            self.chatCoreService.reloadPluginContributions(from: self.pluginService)
            self.lumiUIService.reloadThemes(from: self.pluginService)
            self.menuBarService.refresh()
            self.editorCoreService.reinstallExtensions()
        }

        // 连接插件生命周期回调，处理启用/禁用时的资源清理
        self.pluginService.onPluginLifecycleChange = { [weak self] (plugin, enabled) in
            guard let self else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件生命周期变化: \(plugin.info.id) -> \(enabled ? "启用" : "禁用")")
            }
            // 插件状态变化时通知相关服务清理资源
            // 例如：清理 UI 缓存、通知编辑器重新加载等
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)🎉 RootContainer 初始化完成")
        }
    }
}
