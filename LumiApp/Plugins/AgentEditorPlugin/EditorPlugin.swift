import Foundation
import SwiftUI
import os
import MagicKit
import Combine

/// Editor Plugin: 代码编辑器 + 文件树 + 聊天栏
///
/// 整合了文件树（ProjectTree）、代码编辑器（LumiEditor）和聊天界面为一个插件，
/// 统一通过 `addPanelView()` 提供面板视图。
/// 聊天栏（消息列表 + 输入区 + 自动批准开关）作为编辑器的右侧栏内嵌。
actor EditorPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")

    nonisolated static let emoji = "✏️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    static let id: String = "LumiEditor"
    static let displayName: String = String(localized: "Code Editor", table: "LumiEditor")
    static let description: String = String(localized: "Code editor with file tree", table: "LumiEditor")
    static let iconName: String = "chevron.left.forwardslash.chevron.right"
    static var isConfigurable: Bool { false }
    static var order: Int { 77 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorPlugin()

    // MARK: - UI Contributions

    /// 包裹 RootView：确保文件选中监听、编辑器初始化生效，
    /// 以及自动批准设置的持久化（按项目隔离）
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(
            EditorRootOverlay(
                content: AutoApprovePersistenceOverlay(content: content())
            )
        )
    }

    /// 面板视图：文件树 + 编辑器 + 聊天栏
    @MainActor func addPanelView() -> AnyView? {
        AnyView(EditorPanelView())
    }

    /// 在全局状态栏右侧显示 Editor 插件入口
    @MainActor func addStatusBarTrailingView() -> AnyView? {
        AnyView(EditorLoadedPluginsStatusBarView())
    }
}
