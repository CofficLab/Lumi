import Foundation
import SwiftUI
import os
import MagicKit

/// Project Tree Plugin: 显示项目文件树状结构，使用 SwiftUI 开发
actor ProjectTreePlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree")

    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "🌳"

    /// Whether to enable this plugin
    nonisolated static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = true

    /// Plugin unique identifier
    static let id: String = "ProjectTree"

    /// Plugin display name
    static let displayName: String = String(localized: "Project File Tree", table: "ProjectTree")

    /// Plugin functional description
    static let description: String = String(localized: "Show project file directory structure", table: "ProjectTree")

    /// Plugin icon name
    static let iconName: String = "folder.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = false

    /// Registration order
    static var order: Int { 75 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = ProjectTreePlugin()

    /// Initialization method
    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ ProjectTreePlugin 初始化完成")
        }
    }

    // MARK: - UI Contributions

    /// Add sidebar view for Agent mode - 显示项目文件树
    /// - Returns: ProjectTreeView to be added to the sidebar
    @MainActor func addSidebarView() -> AnyView? {
        if Self.verbose {
            Self.logger.info("\(Self.t)📋 addSidebarView 被调用")
        }
        return AnyView(ProjectTreeView())
    }
}
