import MagicKit
import SwiftUI
import os

actor ClipboardManagerPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.clipboard-manager")

    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    static let id = "ClipboardManager"
    static let navigationId = "clipboard_manager"
    static let displayName = String(localized: "Clipboard", table: "ClipboardManager")
    static let description = String(localized: "Manage clipboard history and snippets", table: "ClipboardManager")
    static let iconName = "doc.on.clipboard"
    static var order: Int { 70 }
    nonisolated static let enable: Bool = true
    nonisolated static let isConfigurable: Bool = true

    static let shared = ClipboardManagerPlugin()
    nonisolated private static let settingsStore = ClipboardManagerPluginLocalStore()
    nonisolated private static let monitoringKey = "ClipboardMonitoringEnabled"

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        // Initialize defaults
        Self.settingsStore.migrateLegacyValueIfMissing(forKey: Self.monitoringKey)
        if Self.settingsStore.object(forKey: Self.monitoringKey) == nil {
            Self.settingsStore.set(true, forKey: Self.monitoringKey)
        }
    }

    nonisolated func onEnable() {
        Task { @MainActor in
            if Self.settingsStore.bool(forKey: Self.monitoringKey) {
                ClipboardMonitor.shared.startMonitoring()
            }
        }
    }

    nonisolated func onDisable() {
        Task { @MainActor in
            ClipboardMonitor.shared.stopMonitoring()
        }
    }

    // MARK: - UI

    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                ClipboardHistoryView()
            },
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(ClipboardManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
