import SwiftUI
import MagicKit

actor TerminalPlugin: SuperPlugin {
    nonisolated static let emoji = "💻"
    nonisolated static let verbose = true
    
    static let id = "Terminal"
    static let navigationId = "terminal"
    static let displayName = "Terminal"
    static let description = "Interactive terminal emulator"
    static let iconName = "terminal"
    static var order: Int { 90 }
    
    static let shared = TerminalPlugin()
    
    // MARK: - Lifecycle
    
    nonisolated func onRegister() {
    }
    
    nonisolated func onEnable() {
    }
    
    nonisolated func onDisable() {
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
                TerminalMainView()
            }
        ]
    }
}
