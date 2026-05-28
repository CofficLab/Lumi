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
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "数据库工作台",
                subtitle: "管理 SQLite、MySQL、PostgreSQL 和 Redis 连接，并让助手只读查询。",
                icon: Self.iconName,
                accent: .teal,
                metrics: [
                    PluginPosterSupport.metric("SQL", "查询"),
                    PluginPosterSupport.metric("Redis", "缓存"),
                ],
                rows: ["连接列表", "Schema 查看", "只读查询工具"],
                chips: ["数据库", "开发工具", "Agent 工具"]
            ),
        ]
    }

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
