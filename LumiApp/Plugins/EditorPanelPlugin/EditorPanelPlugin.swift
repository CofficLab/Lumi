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
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    static let id: String = "LumiEditor"
    static let displayName: String = String(localized: "Code Editor", table: "LumiEditor")
    static let description: String = String(
        localized: "Code editor with file tree", table: "LumiEditor")
    static let iconName = "chevron.left.forwardslash.chevron.right"
    static var isConfigurable: Bool { false }
    static var category: PluginCategory { .editor }
    static var order: Int { 77 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorPlugin()

    // MARK: - UI Contributions

    /// 面板视图：编辑器
    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(EditorPanelView())
        }
    }
}
