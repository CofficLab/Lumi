import Foundation
import SwiftUI
import os
import MagicKit

/// Agent Recent Projects Sidebar Plugin: 侧边栏显示最近项目列表
actor AgentRecentProjectsSidebarPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.recent-projects-sidebar")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "📋"
    nonisolated static let enable = true
    nonisolated static let verbose = false

    static let id: String = "AgentRecentProjectsSidebar"
    static let displayName: String = String(localized: "Recent Projects", table: "AgentRecentProjectsSidebar")
    static let description: String = String(localized: "Show recent projects in sidebar", table: "AgentRecentProjectsSidebar")
    static let iconName: String = "clock.arrow.circlepath"
    static let isConfigurable: Bool = false
    static var order: Int { 75 }

    nonisolated var instanceLabel: String {
        Self.id
    }

    static let shared = AgentRecentProjectsSidebarPlugin()

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ AgentRecentProjectsSidebarPlugin 初始化完成")
        }
    }

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 AgentRecentProjectsSidebarPlugin 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(self.t)✅ AgentRecentProjectsSidebarPlugin 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(self.t)⛔️ AgentRecentProjectsSidebarPlugin 已禁用")
        }
    }

    // MARK: - Views

    @MainActor
    func addSidebarView() -> AnyView? {
        return AnyView(RecentProjectsSidebarView())
    }
}