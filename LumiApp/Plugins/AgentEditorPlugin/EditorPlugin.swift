import Combine
import Foundation
import MagicKit
import SwiftUI
import os

/// Editor Plugin: 代码编辑器 + 文件树
actor EditorPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")

    nonisolated static let emoji = "✏️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "LumiEditor"
    static let displayName: String = String(localized: "Code Editor", table: "LumiEditor")
    static let description: String = String(
        localized: "Code editor with file tree", table: "LumiEditor")
    static let iconName: String = "chevron.left.forwardslash.chevron.right"
    static var isConfigurable: Bool { false }
    static var order: Int { 77 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorPlugin()

    // MARK: - UI Contributions

    /// 包裹 RootView：确保文件选中监听、编辑器初始化生效
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView?
    where Content: View {
        AnyView(
            EditorRootOverlay(
                content: content()
            )
        )
    }

    /// 面板视图：文件树 + 编辑器
    @MainActor func addPanelView() -> AnyView? {
        AnyView(EditorPanelView())
    }

    /// 编辑器面板需要右侧栏（聊天）
    nonisolated var panelNeedsSidebar: Bool { true }

    /// 在工具栏显示 Xcode 项目状态
    @MainActor func addToolBarLeadingView() -> AnyView? {
        guard XcodeProjectContextBridge.shared.isXcodeProject else { return nil }
        return AnyView(XcodeProjectStatusBar())
    }

    /// 在状态栏右侧显示已加载插件入口
    @MainActor func addStatusBarTrailingView() -> AnyView? {
        AnyView(EditorLoadedPluginsStatusBarView())
    }
}
