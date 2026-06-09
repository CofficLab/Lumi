import LumiCoreKit
import EditorService
import SuperLogKit
import Foundation
import SwiftUI
import os

@MainActor
public enum EditorBottomSearchBridge {
    public static var editorServiceProvider: ((PluginContext) -> EditorService?)?
}

/// 编辑器底部面板 - Search 标签页插件
///
/// 向内核全局底部面板注册 Search Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
public actor EditorBottomSearchPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .optOut
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-search")

    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false
    public static let id: String = "EditorBottomSearch"
    public static let displayName: String = String(localized: "Editor Bottom Search", bundle: .module)
    public static let description: String = String(localized: "Search panel in the editor bottom area", bundle: .module)
    public static let iconName: String = "magnifyingglass"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 79 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorBottomSearchPlugin()

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        EditorBottomSearchBridge.editorServiceProvider = { pluginContext in
            context.editorServiceProvider(pluginContext) as? EditorService
        }
    }

    // MARK: - Bottom Panel Tabs

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return [] }
        return [
            BottomPanelTab(
                id: "editor-bottom-search",
                title: String(localized: "Search", bundle: .module),
                systemImage: "magnifyingglass",
                priority: 2
            ),
        ]
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "editor-bottom-search",
              context.activeIcon == "chevron.left.forwardslash.chevron.right",
              let service = EditorBottomSearchBridge.editorServiceProvider?(context) else { return nil }
        return AnyView(BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true))
    }
}
