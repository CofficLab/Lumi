import LumiCoreKit
import EditorService
import SuperLogKit
import Foundation
import SwiftUI
import os

@MainActor
public enum EditorBottomSymbolsBridge {
    public static var editorServiceProvider: ((PluginContext) -> EditorService?)?
}

/// 编辑器底部面板 - Workspace Symbols 标签页插件
///
/// 向内核全局底部面板注册 Workspace Symbols Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
public actor EditorBottomSymbolsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .optOut
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-symbols")

    public nonisolated static let emoji = "🔣"
    public nonisolated static let verbose: Bool = false
    public static let id: String = "EditorBottomSymbols"
    public static let displayName: String = String(localized: "Editor Bottom Symbols", bundle: .module)
    public static let description: String = String(localized: "Workspace Symbols panel in the editor bottom area", bundle: .module)
    public static let iconName: String = "text.magnifyingglass"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 79 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorBottomSymbolsPlugin()

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        EditorBottomSymbolsBridge.editorServiceProvider = { pluginContext in
            context.editorServiceProvider(pluginContext) as? EditorService
        }
    }

    // MARK: - Bottom Panel Tabs

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return [] }
        return [
            BottomPanelTab(
                id: "editor-bottom-symbols",
                title: String(localized: "Workspace Symbols", bundle: .module),
                systemImage: "text.magnifyingglass",
                priority: 3
            ),
        ]
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "editor-bottom-symbols",
              context.activeIcon == "chevron.left.forwardslash.chevron.right",
              let service = EditorBottomSymbolsBridge.editorServiceProvider?(context) else { return nil }
        return AnyView(BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false))
    }
}
