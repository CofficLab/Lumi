import os
import SwiftUI
import LumiCoreKit

actor ClipboardManagerPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.clipboard-manager")

    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    static let id = "ClipboardManager"
    static let navigationId = "clipboard_manager"
    static let displayName = String(localized: "Clipboard", table: "ClipboardManager")
    static let description = String(localized: "Manage clipboard history and snippets", table: "ClipboardManager")
    static let iconName = "doc.on.clipboard"
    static var category: PluginCategory { .general }
    static var order: Int { 70 }
    static let policy: PluginPolicy = .optIn

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
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(ClipboardHistoryView())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
