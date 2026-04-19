import Foundation
import SwiftUI
import os
import MagicKit
import Combine

/// Editor Plugin: 代码编辑器
actor EditorPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")

    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "✏️"

    /// Whether to enable this plugin
    nonisolated static let enable: Bool = true
    /// Whether to enable verbose log output
    nonisolated static let verbose: Bool = false
    /// Plugin unique identifier
    static let id: String = "LumiEditor"

    /// Plugin display name
    static let displayName: String = String(localized: "Code Editor", table: "LumiEditor")

    /// Plugin functional description
    static let description: String = String(localized: "Professional code editor with syntax highlighting, code folding, minimap, and find/replace", table: "LumiEditor")

    /// Plugin icon name
    static let iconName: String = "chevron.left.forwardslash.chevron.right"

    /// Whether it is configurable
    static let isConfigurable: Bool = false

    /// Registration order
    static var order: Int { 77 }

    // MARK: - Instance

    /// Plugin instance label
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = EditorPlugin()

    // MARK: - UI Contributions

    /// 包裹 RootView，确保文件选择监听始终生效
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(EditorRootOverlay(content: content()))
    }

    /// Add detail view - 显示代码编辑器（内含状态栏）
    @MainActor func addDetailView() -> AnyView? {
        AnyView(EditorRootView())
    }
}
