import Combine
import Foundation
import LumiCoreKit
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// 代码编辑器
public actor EditorPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")

    public nonisolated static let emoji = "✏️"
    public nonisolated static let verbose: Bool = false
    public static let id: String = "LumiEditor"
    public static let displayName: String = String(localized: "Code Editor", bundle: .module)
    public static let description: String = String(localized: "Code editor with file tree", bundle: .module)
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 77 }
    public nonisolated static let policy: PluginPolicy = .optIn

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorPlugin()

    // MARK: - UI Contributions

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(
            id: Self.id,
            title: Self.displayName,
            icon: Self.iconName,
            showsProjectToolbar: true,
            showChat: .narrow,
            showsRail: true,
            showsBottomPanel: true
        ) {
            AnyView(EditorPanelView())
        }
    }
}
