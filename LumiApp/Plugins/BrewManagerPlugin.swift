import PluginBrewManager
import SwiftUI
import os

actor BrewManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")

    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🍺"
    nonisolated static let verbose: Bool = PluginBrewManager.BrewManagerPlugin.verbose

    static let id = PluginBrewManager.BrewManagerPlugin.id
    static let navigationId = PluginBrewManager.BrewManagerPlugin.navigationId
    static let displayName = PluginBrewManager.BrewManagerPlugin.displayName
    static let description = PluginBrewManager.BrewManagerPlugin.description
    static let iconName = PluginBrewManager.BrewManagerPlugin.iconName
    static var category: PluginCategory { .developerTool }
    static var order: Int { 60 }
    nonisolated static let policy: PluginPolicy = .optIn
    nonisolated var instanceLabel: String { Self.id }
    static let shared = BrewManagerPlugin()
    
    // MARK: - UI Contributions

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginBrewManager.BrewManagerPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }
}
