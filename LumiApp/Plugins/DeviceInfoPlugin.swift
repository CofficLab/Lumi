import AgentToolKit
import PluginDeviceInfo
import SwiftUI
import os

actor DeviceInfoPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.device-info")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"
    static var category: PluginCategory { .general }
    nonisolated static let verbose: Bool = PluginDeviceInfo.DeviceInfoPlugin.verbose

    static let id: String = PluginDeviceInfo.DeviceInfoPlugin.id
    static let navigationId: String = PluginDeviceInfo.DeviceInfoPlugin.navigationId
    static let displayName: String = PluginDeviceInfo.DeviceInfoPlugin.displayName
    static let description: String = PluginDeviceInfo.DeviceInfoPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginDeviceInfo.DeviceInfoPlugin.description(for: language)
    }
    static let iconName = PluginDeviceInfo.DeviceInfoPlugin.iconName
    static var order: Int { PluginDeviceInfo.DeviceInfoPlugin.order }
    nonisolated static let policy: PluginPolicy = .optIn

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = DeviceInfoPlugin()

    nonisolated func onEnable() {
        PluginDeviceInfo.DeviceInfoPlugin.shared.onEnable()
    }

    nonisolated func onDisable() {
        PluginDeviceInfo.DeviceInfoPlugin.shared.onDisable()
    }

    // MARK: - UI Contributions

    @MainActor
    func addMenuBarContentView() -> AnyView? {
        PluginDeviceInfo.DeviceInfoPlugin.shared.addMenuBarContentView()
    }

    @MainActor
    func addMenuBarPopupViews() -> [AnyView] {
        PluginDeviceInfo.DeviceInfoPlugin.shared.addMenuBarPopupViews()
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginDeviceInfo.DeviceInfoPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }
}
