import LayoutPlugin
import LumiChatKit
import LumiCoreKit
import LumiUI
import ProjectsPlugin
import SwiftUI

@MainActor
final class RootContainer: ObservableObject {
    static let shared = RootContainer()

    let lumiCoreService: LumiCoreService
    let pluginService: PluginService
    let toolService: ToolService
    let projectPathStore: LumiCurrentProjectPathStore
    let editorCoreService: EditorCoreService
    let chatCoreService: ChatCoreService
    let chatSectionCoordinator: ChatSectionCoordinator
    let lumiUIService: LumiUIService
    let menuBarService: MenuBarService

    private init() {
        self.lumiCoreService = LumiCoreService()
        self.pluginService = PluginService()
        self.toolService = ToolService()
        self.projectPathStore = LumiCurrentProjectPathStore()
        // ProjectsPlugin 负责项目数据的存储，在 ChatCoreService 之前初始化
        ProjectsPlugin.setupStore(projectPathStore: projectPathStore)
        self.editorCoreService = EditorCoreService(
            pluginService: pluginService,
            persistenceRootURL: { AppConfig.getDBFolderURL() },
            recentProjects: { [] }
        )
        self.chatCoreService = ChatCoreService(
            lumiCoreService: lumiCoreService,
            pluginService: pluginService,
            toolService: toolService,
            projectPathStore: projectPathStore
        )
        self.chatSectionCoordinator = ChatSectionCoordinator(
            chatService: chatCoreService.chatService,
            databaseDirectory: lumiCoreService.coreDatabaseDirectory
        )
        self.lumiUIService = LumiUIService(pluginService: pluginService)
        self.menuBarService = MenuBarService(pluginService: pluginService)
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
        LayoutPlugin.restorePersistedStateIfNeeded()
        self.pluginService.onEnabledPluginsChanged = { [weak self] in
            guard let self else { return }
            self.chatCoreService.reloadPluginContributions(from: self.pluginService)
            self.lumiUIService.reloadThemes(from: self.pluginService)
            self.menuBarService.refresh()
            self.editorCoreService.reinstallExtensions()
        }
    }
}
