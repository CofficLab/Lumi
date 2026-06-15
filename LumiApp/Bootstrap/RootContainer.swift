import LayoutPlugin
import LumiChatKit
import LumiCoreKit
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
        _ = UpdateController.shared
        Task {
            await UpdateController.shared.setupFeedURLIfNeeded()
        }
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
