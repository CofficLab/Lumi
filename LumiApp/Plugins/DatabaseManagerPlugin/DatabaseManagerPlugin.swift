import MagicKit
import SwiftUI

actor DatabaseManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🗄️"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = true

    static let id = "DatabaseManager"
    static let navigationId = "database_manager"
    static let displayName = String(localized: "Database", table: "DatabaseManager")
    static let description = String(localized: "Manage SQLite, MySQL, PostgreSQL, and Redis", table: "DatabaseManager")
    static let iconName = "server.rack"
    static var order: Int { 50 }
    nonisolated var instanceLabel: String { Self.id }
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
        .withNavigation(DatabaseManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
