import MagicKit
import SwiftUI

actor DatabaseManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🗄️"
    static let enable = true
    nonisolated static let verbose = true

    static let id = "DatabaseManager"
    static let navigationId = "database_manager"
    static let displayName = "数据库管理"
    static let description = "Manage SQLite, MySQL, and PostgreSQL databases"
    static let iconName = "server.rack"
    static var order: Int { 50 }

    static let shared = DatabaseManagerPlugin()

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
            },
        ]
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(DatabaseManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
