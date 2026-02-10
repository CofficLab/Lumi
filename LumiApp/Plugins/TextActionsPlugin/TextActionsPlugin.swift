import SwiftUI
import MagicKit

actor TextActionsPlugin: SuperPlugin {
    nonisolated static let emoji = "🖱️"
    nonisolated static let verbose = true
    
    static let id = "TextActions"
    static let navigationId = "text_actions"
    static let displayName = "Text Actions"
    static let description = "Selected text actions menu"
    static let iconName = "cursorarrow.click.2"
    static var order: Int { 60 }
    
    static let shared = TextActionsPlugin()
    
    // MARK: - Lifecycle
    
    nonisolated func onRegister() {
        // Initialize settings default if not set
        if UserDefaults.standard.object(forKey: "TextActionsEnabled") == nil {
            UserDefaults.standard.set(false, forKey: "TextActionsEnabled")
        }
    }
    
    nonisolated func onEnable() {
        Task { @MainActor in
            if UserDefaults.standard.bool(forKey: "TextActionsEnabled") {
                TextSelectionManager.shared.startMonitoring()
                _ = TextActionMenuController.shared
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
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                TextActionsSettingsView()
            }
        ]
    }
}
