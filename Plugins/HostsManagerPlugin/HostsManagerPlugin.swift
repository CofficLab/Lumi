import SwiftUI
import MagicKit

actor HostsManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "📝"
    static let enable = true
    nonisolated static let verbose = true
    
    static let id = "HostsManager"
    static let displayName = "Hosts 管理"
    static let description = "管理系统 Hosts 文件配置"
    static let iconName = "list.bullet.rectangle"
    static var order: Int { 21 }
    
    nonisolated var instanceLabel: String { Self.id }
    
    static let shared = HostsManagerPlugin()
    
    init() {}
    
    // MARK: - UI Contributions
    
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: "hosts_manager",
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                HostsManagerView()
            }
        ]
    }
}
