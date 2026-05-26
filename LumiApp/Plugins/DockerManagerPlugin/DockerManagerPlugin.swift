import PluginDockerManager
import SwiftUI
import os

actor DockerManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docker-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🐳"
    nonisolated static let enable: Bool = PluginDockerManager.DockerManagerPlugin.enable
    nonisolated static let verbose: Bool = PluginDockerManager.DockerManagerPlugin.verbose

    static let id = PluginDockerManager.DockerManagerPlugin.id
    static let navigationId = PluginDockerManager.DockerManagerPlugin.navigationId
    static let displayName = PluginDockerManager.DockerManagerPlugin.displayName
    static let description = PluginDockerManager.DockerManagerPlugin.description
    static let iconName = PluginDockerManager.DockerManagerPlugin.iconName
    static var category: PluginCategory { .developerTool }
    static var order: Int { 50 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DockerManagerPlugin()

    private init() {}

    // MARK: - UI Contributions

    

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        PluginDockerManager.DockerManagerPlugin.shared.addPanelView(activeIcon: activeIcon)
    }

    nonisolated func addPanelIcon() -> String? {
        PluginDockerManager.DockerManagerPlugin.shared.addPanelIcon()
    }
}
