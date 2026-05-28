import AgentToolKit
import PluginAppUpdateStatusBar
import SwiftUI
import os

actor AppUpdateStatusBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-update-status-bar")

    nonisolated static let emoji = "⬆️"
    static var category: PluginCategory { .general }
    nonisolated static let verbose: Bool = PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.verbose

    static let id = PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.id
    static let navigationId = PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.navigationId
    static let displayName = PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.displayName
    static let description = PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.description(for: language)
    }
    static let iconName = PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.iconName
    static var order: Int { PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppUpdateStatusBarPlugin()

    nonisolated func onEnable() {
        PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.shared.onEnable()
    }

    nonisolated func onDisable() {
        PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.shared.onDisable()
    }

    @MainActor
    func addMenuBarContentView() -> AnyView? {
        PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.shared.addMenuBarContentView()
    }

    @MainActor
    func addMenuBarPopupView() -> AnyView? {
        PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.shared.addMenuBarPopupView()
    }
}
