import MagicKit
import os
import SwiftUI

/// 最近项目插件
/// 负责保存和恢复最近使用的项目列表，提供当前项目管理工具
///
/// 通过工具栏提供项目选择器和最近项目入口。
actor RecentProjectsPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.recent-projects")

    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false
    static let id = "RecentProjects"
    static let displayName = String(localized: "Recent Projects", table: "RecentProjects")
    static let description = String(localized: "Persist recent projects list and manage current project", table: "RecentProjects")
    static let iconName = "clock.arrow.circlepath"
    static var order: Int { 10 }
    static let enable: Bool = true

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { false }

    static let shared = RecentProjectsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(RecentProjectsPersistenceOverlay(content: content()))
    }

    @MainActor
    func agentTools() -> [AgentTool] {
        [
            ListRecentProjectsTool(),
            GetCurrentProjectTool(),
//            SetCurrentProjectTool(),
            AddProjectTool(),
            GetCurrentFileTool(),
            SetCurrentFileTool(),
        ]
    }

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        []
    }

    // MARK: - Toolbar Views

    /// 工具栏右侧：整合项目名 + 最近项目管理
    @MainActor
    func addToolBarTrailingView() -> AnyView? {
        AnyView(ProjectControlView())
    }
}
