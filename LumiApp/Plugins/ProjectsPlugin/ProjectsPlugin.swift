import Foundation
import AgentToolKit
import LumiCoreKit
import SwiftUI
import os

/// 最近项目管理插件：在工具栏显示当前项目名称并支持切换
///
/// 管理全局最近项目列表，以及项目管理相关的 Agent 工具。
/// 各窗口的当前项目快照由 `WindowPersistencePlugin` 负责保存。
actor ProjectsPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")

    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    static let id: String = "Projects"
    static let displayName: String = String(localized: "Projects", table: "Projects")
    static let description: String = String(localized: "Manage the global projects list", table: "Projects")
    static let iconName: String = "folder"
    static var category: PluginCategory { .general }
    static var order: Int { 10 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ProjectsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "项目切换中心",
                subtitle: "维护最近项目列表，并把当前项目上下文提供给工具和助手。",
                icon: Self.iconName,
                accent: .blue,
                metrics: [
                    PluginPosterSupport.metric("Recent", "最近项目"),
                    PluginPosterSupport.metric("Context", "上下文"),
                ],
                rows: ["工具栏项目选择器", "无项目引导", "Agent 项目工具"],
                chips: ["项目", "上下文", "工具栏"]
            ),
        ]
    }

    /// 在工具栏中间位置显示当前项目选择器
    ///
    /// 当激活的视图容器声明了 `showsProjectToolbar` 时显示。
    @MainActor func addToolBarCenterView(context: PluginContext) -> AnyView? {
        guard context.showsProjectToolbar else { return nil }

        return AnyView(ProjectControlView())
    }

    /// 根视图包裹：用于恢复最近项目列表，并在未选项目时显示引导
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ProjectsOverlay(content: content()))
    }

    // MARK: - Agent Tools

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            ListProjectsTool(),
            GetCurrentProjectTool(),
            AddProjectTool(recentProjectsVM: context.recentProjectsVM),
        ]
    }

    // MARK: - Agent Middlewares

    /// 提供项目上下文注入中间件
    nonisolated func sendMiddlewares() -> [any SuperSendMiddleware.Type]? {
        [CurrentProjectSendMiddleware.self, ProjectsSendMiddleware.self]
    }
}
