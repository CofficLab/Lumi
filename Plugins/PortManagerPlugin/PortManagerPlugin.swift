import SwiftUI
import MagicKit

actor PortManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🔌"
    static let enable = true
    nonisolated static let verbose = true
    
    static let id = "PortManager"
    static let displayName = "端口管理"
    static let description = "查看和管理端口占用情况"
    static let iconName = "network"
    static var order: Int { 20 }
    
    nonisolated var instanceLabel: String { Self.id }
    
    static let shared = PortManagerPlugin()
    
    init() {}
    
    // MARK: - UI Contributions
    
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: "port_manager",
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                PortManagerView()
            }
        ]
    }
}
