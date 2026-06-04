import LumiCoreKit
import EditorService
import SuperLogKit
import Foundation
import SwiftUI
import os

@MainActor
public enum EditorBottomCallHierarchyBridge {
    public static var editorServiceProvider: ((PluginContext) -> EditorService?)?
}

/// 编辑器底部面板 - Call Hierarchy 标签页插件
///
/// 向内核全局底部面板注册 Call Hierarchy Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
public actor EditorBottomCallHierarchyPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .optOut
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-call-hierarchy")

    public nonisolated static let emoji = "📞"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorBottomCallHierarchy"
    public static let displayName: String = String(localized: "Editor Bottom Call Hierarchy", bundle: .module)
    public static let description: String = String(localized: "Call Hierarchy panel in the editor bottom area", bundle: .module)
    public static let iconName: String = "point.3.connected.trianglepath.dotted"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 79 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorBottomCallHierarchyPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return [] }
        return [
            BottomPanelTab(
                id: "editor-bottom-call-hierarchy",
                title: String(localized: "Call Hierarchy", bundle: .module),
                systemImage: "point.3.connected.trianglepath.dotted",
                priority: 4
            ),
        ]
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "editor-bottom-call-hierarchy",
              context.activeIcon == "chevron.left.forwardslash.chevron.right",
              let service = EditorBottomCallHierarchyBridge.editorServiceProvider?(context) else { return nil }
        return AnyView(BottomEditorCallHierarchyPanelView(service: service, showsHeader: false))
    }
}
