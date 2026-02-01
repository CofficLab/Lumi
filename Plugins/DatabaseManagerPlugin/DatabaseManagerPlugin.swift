import SwiftUI
import MagicKit

actor DatabaseManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🗄️"
    static let enable = true
    nonisolated static let verbose = true
    
    static let id = "DatabaseManager"
    static let navigationId = "database_manager"
    static let displayName = "Database Manager"
    static let description = "Manage SQLite, MySQL, and PostgreSQL databases"
    static let iconName = "server.rack"
    static var order: Int { 50 }
    
    nonisolated var instanceLabel: String { Self.id }
    
    static let shared = DatabaseManagerPlugin()
    
    init() {}
    
    // MARK: - UI Contributions
    
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                DatabaseMainView()
            }
        ]
    }
}
