import SwiftUI
import os

actor AppUpdateStatusBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-update-status-bar")

    nonisolated static let emoji = "⬆️"
    static var category: PluginCategory { .general }
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "AppUpdateStatusBar"
    static let navigationId = "app_update_status_bar"
    static let displayName = String(localized: "App Update Status", table: "AppUpdateStatusBar")
    static let description = String(localized: "Shows a menu bar reminder when an app update is ready to install.", table: "AppUpdateStatusBar")
    static let iconName = "arrow.down.circle"
    static let isConfigurable: Bool = false
    static var order: Int { 8 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppUpdateStatusBarPlugin()

    nonisolated func onEnable() {
        Task { @MainActor in
            AppUpdateStatusBarStore.shared.start()
        }
    }

    nonisolated func onDisable() {
        Task { @MainActor in
            AppUpdateStatusBarStore.shared.stop()
        }
    }

    @MainActor
    func addMenuBarContentView() -> AnyView? {
        AnyView(AppUpdateStatusBarContentView(store: AppUpdateStatusBarStore.shared))
    }

    @MainActor
    func addMenuBarPopupView() -> AnyView? {
        AnyView(AppUpdateStatusBarPopupView(store: AppUpdateStatusBarStore.shared))
    }
}
