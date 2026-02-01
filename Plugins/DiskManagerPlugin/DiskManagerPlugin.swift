import SwiftUI
import MagicKit

actor DiskManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "💿"
    static let enable = true
    nonisolated static let verbose = true
    
    static let id = "DiskManager"
    static let displayName = "磁盘管理"
    static let description = "磁盘空间分析与大文件清理"
    static let iconName = "internaldrive"
    static var order: Int { 22 }
    
    nonisolated var instanceLabel: String { Self.id }
    
    static let shared = DiskManagerPlugin()
    
    init() {}
    
    // MARK: - UI Contributions
    
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: "disk_manager",
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                DiskManagerView()
            }
        ]
    }
}
