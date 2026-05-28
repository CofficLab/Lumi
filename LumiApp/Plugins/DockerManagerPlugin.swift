import AgentToolKit
import PluginDockerManager
import SwiftUI
import os

actor DockerManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docker-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🐳"
    nonisolated static let verbose: Bool = PluginDockerManager.DockerManagerPlugin.verbose

    static let id = PluginDockerManager.DockerManagerPlugin.id
    static let navigationId = PluginDockerManager.DockerManagerPlugin.navigationId
    static let displayName = PluginDockerManager.DockerManagerPlugin.displayName
    static let description = PluginDockerManager.DockerManagerPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginDockerManager.DockerManagerPlugin.description(for: language)
    }
    static let iconName = PluginDockerManager.DockerManagerPlugin.iconName
    static var category: PluginCategory { .developerTool }
    static var order: Int { 50 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DockerManagerPlugin()

    private init() {}

    // MARK: - UI Contributions

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginDockerManager.DockerManagerPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }
}
