import Foundation
import SwiftUI
import os
import MagicKit

/// 显示项目文件树状结构
actor ProjectTreePlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree")

    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "🌳"

    /// Whether to enable this plugin
    nonisolated static let enable: Bool = true
    /// Whether to enable verbose log output
    nonisolated static let verbose: Bool = true
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

    // MARK: - UI Contributions

    /// 根层包裹：有文件被选中时切换到文件树侧边栏（不依赖侧边栏内视图是否已挂载）
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ProjectTreeRootOverlay(content: content()))
    }

    /// Add sidebar view for Agent mode - 显示项目文件树
    /// - Returns: ProjectTreeView to be added to the sidebar
    @MainActor func addSidebarView() -> AnyView? {
        AnyView(ProjectTreeView())
    }
}
