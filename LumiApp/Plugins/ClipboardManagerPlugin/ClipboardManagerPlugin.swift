import SwiftUI
import MagicKit

actor ClipboardManagerPlugin: SuperPlugin {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = true
    
    static let id = "ClipboardManager"
    static let navigationId = "clipboard_manager"
    static let displayName = String(localized: "Clipboard")
    static let description = String(localized: "Manage clipboard history and snippets")
    static let iconName = "doc.on.clipboard"
    static var order: Int { 70 }
    
    static let shared = ClipboardManagerPlugin()
    
    // MARK: - Lifecycle
    
    nonisolated func onRegister() {
        // Initialize defaults
        if UserDefaults.standard.object(forKey: "ClipboardMonitoringEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "ClipboardMonitoringEnabled")
        }
    }
    
    nonisolated func onEnable() {
        Task { @MainActor in
            if UserDefaults.standard.bool(forKey: "ClipboardMonitoringEnabled") {
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
    
    @MainActor
    func addDetailView() -> AnyView? {
        return AnyView(ClipboardSettingsView())
    }
}
