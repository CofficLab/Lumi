import MagicKit
import SwiftUI
import os

/// 最近项目持久化插件
/// 负责保存和恢复最近使用的项目列表，提供当前项目管理工具，并在侧边栏显示最近项目
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

    static let shared = RecentProjectsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(RecentProjectsPersistenceOverlay(content: content()))
    }

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] { [] }

    @MainActor
    func agentTools() -> [AgentTool] {
        [
            ListRecentProjectsTool(),
            GetCurrentProjectTool(),
            SetCurrentProjectTool(),
            AddProjectTool(),
        ]
    }

    // MARK: - Sidebar View

    @MainActor
    func addSidebarView() -> AnyView? {
        return AnyView(RecentProjectsSidebarView())
    }
}
