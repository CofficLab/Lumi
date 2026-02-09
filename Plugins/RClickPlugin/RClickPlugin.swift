import SwiftUI
import MagicKit

actor RClickPlugin: SuperPlugin {
    nonisolated static let id = "RClick"
    nonisolated static let displayName = "右键菜单"
    nonisolated static let description = "自定义 Finder 右键菜单动作"
    nonisolated static let iconName = "cursorarrow.click.2"
    static var order: Int { 50 }
    
    static let shared = RClickPlugin()
    
    // MARK: - Lifecycle
    
    nonisolated func onRegister() {
        // Initialize config manager on registration
        Task { @MainActor in
            _ = RClickConfigManager.shared
        }
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
                id: Self.id,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                RClickSettingsView()
            }
        ]
    }
}
