import MagicKit
import os
import SwiftUI

/// 最近项目插件
/// 负责保存和恢复最近使用的项目列表，提供当前项目管理工具，在侧边栏显示最近项目，以及在头部显示项目选择器
actor RecentProjectsPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.recent-projects")

    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

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
    func addRightHeaderLeadingView() -> AnyView? {
        AnyView(ChatHeaderLeadingView())
    }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(ProjectButton())]
    }

    @MainActor
    func agentTools() -> [AgentTool] {
        [
            ListRecentProjectsTool(),
            GetCurrentProjectTool(),
            SetCurrentProjectTool(),
            AddProjectTool(),
            GetCurrentFileTool(),
            SetCurrentFileTool(),
        ]
    }

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        []
    }

    // MARK: - Sidebar View

    @MainActor
    func addSidebarView() -> AnyView? {
        return AnyView(RecentProjectsSidebarView())
    }
}
