import Foundation
import SwiftUI
import os
import MagicKit
import Combine

/// 面包屑导航插件：在工具栏显示当前文件路径的导航条
///
/// 作为 Lumi App 的独立插件，提供文件路径的面包屑导航功能。
/// 当用户选择文件时，在工具栏前导位置显示可点击的路径段，
/// 支持点击弹出同级文件/文件夹列表快速导航。
///
/// 同时整合了最近项目管理功能：
/// - 工具栏左侧显示当前项目名（支持下拉选择切换项目）
/// - 工具栏右侧显示面包屑导航
/// - 持久化最近项目列表和当前项目/文件状态
/// - 提供项目管理相关的 Agent 工具
actor BreadcrumbPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.breadcrumb")

    nonisolated static let emoji = "🧭"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "Breadcrumb"
    static let displayName: String = String(localized: "Breadcrumb Navigation", table: "Breadcrumb")
    static let description: String = String(localized: "File path breadcrumb navigation in toolbar", table: "Breadcrumb")
    static let iconName: String = "folder"
    static var isConfigurable: Bool { false }
    static var order: Int { 10 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = BreadcrumbPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    /// 在工具栏前导位置显示面包屑导航（左：项目选择器 + 右：面包屑路径）
    @MainActor func addToolBarLeadingView() -> AnyView? {
        AnyView(BreadcrumbToolBarView())
    }

    /// 根视图包裹：用于持久化最近项目列表和当前项目/文件
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(RecentProjectsPersistenceOverlay(content: content()))
    }

    // MARK: - Agent Tools

    @MainActor
    func agentTools() -> [AgentTool] {
        [
            ListRecentProjectsTool(),
            GetCurrentProjectTool(),
            AddProjectTool(),
            GetCurrentFileTool(),
            SetCurrentFileTool(),
        ]
    }

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        []
    }
}
