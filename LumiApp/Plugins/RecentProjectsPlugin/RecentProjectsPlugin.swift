import Foundation
import SwiftUI
import os
import MagicKit

/// 最近项目管理插件：在工具栏显示当前项目名称并支持切换
///
/// 管理最近项目列表、当前项目/文件状态持久化，
/// 以及项目管理相关的 Agent 工具。
actor RecentProjectsPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.recent-projects")

    nonisolated static let emoji = "📋"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "RecentProjects"
    static let displayName: String = String(localized: "Recent Projects", table: "RecentProjects")
    static let description: String = String(localized: "Manage recent projects and current project state", table: "RecentProjects")
    static let iconName: String = "folder"
    static var isConfigurable: Bool { false }
    static var order: Int { 10 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RecentProjectsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    /// 在工具栏中间位置显示当前项目选择器
    @MainActor func addToolBarCenterView(activeIcon: String?) -> AnyView? {
        let icons = [EditorPlugin.iconName, GitCommitHistoryPlugin.iconName]
        guard icons.contains(activeIcon ?? "") else { return nil }
        
        return AnyView(ProjectControlView())
    }

    /// 根视图包裹：用于持久化最近项目列表和当前项目/文件
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(RecentProjectsPersistenceOverlay(content: content()))
    }

    // MARK: - Agent Tools

    @MainActor
    func agentTools() -> [SuperAgentTool] {
        [
            ListRecentProjectsTool(),
            GetCurrentProjectTool(),
            AddProjectTool(),
        ]
    }
}
