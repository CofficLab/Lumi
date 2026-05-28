import Combine
import Foundation
import SwiftUI
import os

/// 代码编辑器
actor EditorPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")

    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = true
    static let id: String = "LumiEditor"
    static let displayName: String = String(localized: "Code Editor", table: "LumiEditor")
    static let description: String = String(
        localized: "Code editor with file tree", table: "LumiEditor")
    static let iconName = "chevron.left.forwardslash.chevron.right"
    static var category: PluginCategory { .editor }
    static var order: Int { 77 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorPlugin()

    // MARK: - UI Contributions

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "代码编辑器",
                subtitle: "文件树、源码编辑和 AI 聊天入口集中在同一个工作区。",
                icon: Self.iconName,
                accent: .indigo,
                metrics: [
                    PluginPosterSupport.metric("Tree", "文件树"),
                    PluginPosterSupport.metric("AI", "聊天支持"),
                ],
                rows: ["项目文件树", "源码编辑", "命令面板"],
                chips: ["编辑器", "项目", "AI"]
            ),
        ]
    }

    /// 面板视图：编辑器
    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName, showsProjectToolbar: true, supportsAIChat: true) {
            AnyView(EditorPanelView())
        }
    }
}
