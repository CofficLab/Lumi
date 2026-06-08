import SwiftUI

@MainActor
final class RootContainer: ObservableObject {
    static let shared = RootContainer()

    let lumiCoreService: LumiCoreService
    let pluginService: PluginService
    let toolService: ToolService
    let chatCoreService: ChatCoreService
    let lumiUIService: LumiUIService
    let menuBarService: MenuBarService

    private init() {
        self.lumiCoreService = LumiCoreService()
        self.pluginService = PluginService()
        self.toolService = ToolService()
        self.chatCoreService = ChatCoreService(
            lumiCoreService: lumiCoreService,
            pluginService: pluginService,
            toolService: toolService
        )
        self.lumiUIService = LumiUIService(pluginService: pluginService)
        self.menuBarService = MenuBarService(pluginService: pluginService)
        self.pluginService.onEnabledPluginsChanged = { [weak self] in
            guard let self else { return }
            self.chatCoreService.reloadPluginContributions(from: self.pluginService)
            self.lumiUIService.reloadThemes(from: self.pluginService)
            self.menuBarService.refresh()
        }
    }
}
