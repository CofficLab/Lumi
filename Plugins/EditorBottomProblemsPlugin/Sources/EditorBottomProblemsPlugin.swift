import LumiCoreKit
import EditorService
import SuperLogKit
import Foundation
import SwiftUI
import os

@MainActor
public enum EditorBottomProblemsBridge {
    public static var editorServiceProvider: ((PluginContext) -> EditorService?)?
}

/// 编辑器底部面板 - Problems 标签页插件
///
/// 向内核全局底部面板注册 Problems Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
public actor EditorBottomProblemsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .optOut
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-problems")

    public nonisolated static let emoji = "⚠️"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorBottomProblems"
    public static let displayName: String = String(localized: "Editor Bottom Problems", bundle: .module)
    public static let description: String = String(localized: "Problems panel in the editor bottom area", bundle: .module)
    public static let iconName: String = "exclamationmark.bubble"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 79 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorBottomProblemsPlugin()

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        EditorBottomProblemsBridge.editorServiceProvider = { pluginContext in
            context.editorServiceProvider(pluginContext) as? EditorService
        }
    }

    // MARK: - Bottom Panel Tabs

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return [] }
        return [
            BottomPanelTab(
                id: "editor-bottom-problems",
                title: String(localized: "Problems", bundle: .module),
                systemImage: "exclamationmark.bubble",
                priority: 0
            ),
        ]
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "editor-bottom-problems",
              context.activeIcon == "chevron.left.forwardslash.chevron.right",
              let service = EditorBottomProblemsBridge.editorServiceProvider?(context) else { return nil }
        return AnyView(BottomEditorProblemsPanelView(service: service, showsHeader: false))
    }
}
