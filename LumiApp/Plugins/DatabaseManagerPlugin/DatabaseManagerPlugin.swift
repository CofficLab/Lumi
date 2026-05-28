import SwiftUI
import AgentToolKit
import os

actor DatabaseManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.database-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🗄️"
    static var category: PluginCategory { .general }
    nonisolated static let verbose: Bool = true

    static let id = "DatabaseManager"
    static let navigationId = "database_manager"
    static let displayName = String(localized: "Database", table: "DatabaseManager")
    static let description = String(localized: "Manage SQLite, MySQL, PostgreSQL, and Redis", table: "DatabaseManager")
    static let iconName = "server.rack"
    static var order: Int { 50 }

    nonisolated static let policy: PluginPolicy = .optIn
    nonisolated var instanceLabel: String { Self.id }
    static let shared = DatabaseManagerPlugin()
    
    /// 插件注册策略：可配置，默认不启用（可选功能）

    // MARK: - UI Contributions

    

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(DatabaseMainView())
        }
    }

    nonisolated func onDisable() {
        Task {
            await DatabaseManager.shared.shutdown()
        }
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            DatabaseListConnectionsTool(),
            DatabaseDescribeSchemaTool(),
            DatabaseReadonlyQueryTool(),
            DatabaseSampleTableTool(),
        ]
    }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
