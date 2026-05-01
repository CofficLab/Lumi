import MagicKit
import os
import SwiftUI

actor ClipboardManagerPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.clipboard-manager")

    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false
    static let id = "ClipboardManager"
    static let navigationId = "clipboard_manager"
    static let displayName = String(localized: "Clipboard", table: "ClipboardManager")
    static let description = String(localized: "Manage clipboard history and snippets", table: "ClipboardManager")
    static let iconName = "doc.on.clipboard"
    static var order: Int { 70 }
    nonisolated static let enable: Bool = true
    nonisolated static let isConfigurable: Bool = true

    static let shared = ClipboardManagerPlugin()
    private nonisolated static let settingsStore = ClipboardManagerPluginLocalStore.shared
    private nonisolated static let monitoringKey = "ClipboardMonitoringEnabled"

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
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(ClipboardHistoryView())
    }

    nonisolated func addPanelIcon() -> String? { Self.iconName }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
