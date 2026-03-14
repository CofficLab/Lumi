import SwiftUI
import MagicKit

actor ClipboardManagerPlugin: SuperPlugin {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false
    
    static let id = "ClipboardManager"
    static let navigationId = "clipboard_manager"
    static let displayName = String(localized: "Clipboard")
    static let description = String(localized: "Manage clipboard history and snippets")
    static let iconName = "doc.on.clipboard"
    static var order: Int { 70 }
    nonisolated static let enable = true
    
    static let shared = ClipboardManagerPlugin()
    
    // MARK: - Lifecycle
    
    nonisolated func onRegister() {
        // Initialize defaults
        if AppSettingsStore.shared.object(forKey: "ClipboardMonitoringEnabled") == nil {
            AppSettingsStore.shared.set(true, forKey: "ClipboardMonitoringEnabled")
        }
    }
    
    nonisolated func onEnable() {
        Task { @MainActor in
            if AppSettingsStore.shared.bool(forKey: "ClipboardMonitoringEnabled") {
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
            }
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
