import MagicKit
import SwiftUI
import OSLog

actor TextActionsPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🖱️"
    nonisolated static let verbose: Bool = true

    static let id = "TextActions"
    static let navigationId = "text_actions"
    static let displayName = String(localized: "Text Actions", table: "TextActions")
    static let description = String(localized: "Selected text actions menu", table: "TextActions")
    static let iconName = "cursorarrow.click.2"
    nonisolated static let enable: Bool = true
    static var order: Int { 60 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = TextActionsPlugin()
    
    // MARK: - Lifecycle
    
    nonisolated func onRegister() {
        // Initialize settings default if not set
        if AppSettingsStore.shared.object(forKey: "TextActionsEnabled") == nil {
            AppSettingsStore.shared.set(true, forKey: "TextActionsEnabled")
        }
    }
    
    nonisolated func onEnable() {
        Task { @MainActor in
            // Always start monitoring when plugin is enabled
            // The user can toggle the feature on/off in settings view
            TextSelectionManager.shared.startMonitoring()
            _ = TextActionMenuController.shared
            
            if Self.verbose {
                os_log("\(Self.t)✅ Text Actions plugin enabled")
            }
        }
    }
    
    nonisolated func onDisable() {
        Task { @MainActor in
            TextSelectionManager.shared.stopMonitoring()
        }
    }
    
    // MARK: - UI
    
    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.id,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                TextActionsSettingsView()
            }
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(TextActionsPlugin.id)
        .inRootView()
        .withDebugBar()
}
