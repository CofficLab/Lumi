import SwiftUI
import LumiCoreKit
import LumiUI
import SuperLogKit
import AgentToolKit
import os

public actor DatabaseManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.database-manager")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🗄️"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = true

    public static let id = "DatabaseManager"
    public static let navigationId = "database_manager"
    public static let displayName = String(localized: "Database", bundle: .module)
    public static let description = String(localized: "Manage SQLite, MySQL, PostgreSQL, and Redis", bundle: .module)
    public static let iconName = "server.rack"
    public static var order: Int { 50 }

    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = DatabaseManagerPlugin()
    
    /// 插件注册策略：可配置，默认不启用（可选功能）

    // MARK: - UI Contributions

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(DatabaseMainView())
        }
    }

    public nonisolated func onDisable() {
        Task {
            await DatabaseManager.shared.shutdown()
        }
    }

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            DatabaseListConnectionsTool(),
            DatabaseDescribeSchemaTool(),
            DatabaseReadonlyQueryTool(),
            DatabaseSampleTableTool(),
        ]
    }
}
