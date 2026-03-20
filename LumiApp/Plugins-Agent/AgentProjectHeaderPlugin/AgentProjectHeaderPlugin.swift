import MagicKit
import SwiftUI
import os

/// 项目选择头部插件：右侧栏 header 左侧（当前项目信息、未选项目提示）+ 项目按钮
/// 同时提供 `list_recent_projects` 工具，供 AI 助手查询用户最近使用的项目列表。
actor AgentProjectHeaderPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project-header")

    nonisolated static let emoji = "📁"
    nonisolated static let verbose = false

    static let id = "AgentProjectHeader"
    static let displayName = String(localized: "Project Selector", table: "AgentProjectHeader")
    static let description = String(localized: "Select and manage project in chat header", table: "AgentProjectHeader")
    static let iconName = "folder"
    static var order: Int { 81 }
    static let enable: Bool = true

    static let shared = AgentProjectHeaderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

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
        [ListRecentProjectsTool()]
    }
}