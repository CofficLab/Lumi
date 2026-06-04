import LumiCoreKit
import EditorService
import SuperLogKit
import Foundation
import SwiftUI
import os

@MainActor
public enum EditorBottomReferencesBridge {
    public static var editorServiceProvider: ((PluginContext) -> EditorService?)?
}

/// 编辑器底部面板 - References 标签页插件
///
/// 向内核全局底部面板注册 References Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
public actor EditorBottomReferencesPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .optOut
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-references")

    public nonisolated static let emoji = "🔗"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorBottomReferences"
    public static let displayName: String = String(localized: "Editor Bottom References", bundle: .module)
    public static let description: String = String(localized: "References panel in the editor bottom area", bundle: .module)
    public static let iconName: String = "arrow.triangle.branch"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 79 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorBottomReferencesPlugin()

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        EditorBottomReferencesBridge.editorServiceProvider = { pluginContext in
            context.editorServiceProvider(pluginContext) as? EditorService
        }
    }

    // MARK: - Bottom Panel Tabs

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return [] }
        return [
            BottomPanelTab(
                id: "editor-bottom-references",
                title: String(localized: "References", bundle: .module),
                systemImage: "arrow.triangle.branch",
                priority: 1
            ),
        ]
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "editor-bottom-references",
              context.activeIcon == "chevron.left.forwardslash.chevron.right",
              let service = EditorBottomReferencesBridge.editorServiceProvider?(context) else { return nil }
        return AnyView(BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false))
    }
}
