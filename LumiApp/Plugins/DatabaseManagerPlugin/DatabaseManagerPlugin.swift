import MagicKit
import SwiftUI
import os

actor DatabaseManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.database-manager")

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

    /// 该面板不需要右侧栏

    @MainActor func addPanelView() -> AnyView? {
        AnyView(DatabaseMainView())
    }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
