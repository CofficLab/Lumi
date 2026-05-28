import AgentToolKit
import PluginDiskManager
import SwiftUI
import os

actor DiskManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "💿"
    nonisolated static let verbose: Bool = PluginDiskManager.DiskManagerPlugin.verbose

    static let id = PluginDiskManager.DiskManagerPlugin.id
    static let navigationId = PluginDiskManager.DiskManagerPlugin.navigationId
    static let displayName = PluginDiskManager.DiskManagerPlugin.displayName
    static let description = PluginDiskManager.DiskManagerPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginDiskManager.DiskManagerPlugin.description(for: language)
    }
    static let iconName = PluginDiskManager.DiskManagerPlugin.iconName
    static var category: PluginCategory { .system }
    static var order: Int { PluginDiskManager.DiskManagerPlugin.order }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DiskManagerPlugin()

    // MARK: - UI Contributions

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginDiskManager.DiskManagerPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }
}
