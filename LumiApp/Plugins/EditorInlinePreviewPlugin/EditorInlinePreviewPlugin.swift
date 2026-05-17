import Foundation
import LumiInlinePreviewKit
import MagicKit
import SwiftUI
import os

/// 内嵌预览插件（v2 实现路径）。
///
/// 与 `EditorRemoteHotPreviewPlugin` 并行存在，技术核心为：
/// IOSurface 帧流 + Lumi 面板内 `CALayer` 显示，逐步走向"对齐 Xcode Previews"。
///
/// 当前阶段：Phase 1 — 仅打通 IOSurface 显示通路，使用主进程内的
/// `DemoSurfaceFactory` 生成测试帧。Phase 2 起接入子进程帧流。
actor EditorInlinePreviewPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview"
    )

    nonisolated static let emoji = "IP"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    static let id: String = "EditorInlinePreview"
    static let displayName: String = "Inline Preview"
    static let description: String = "Embedded preview powered by LumiInlinePreviewKit"
    static let iconName: String = "rectangle.inset.filled"
    static var isConfigurable: Bool { false }
    static var order: Int { 84 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorInlinePreviewPlugin()

    // MARK: - 底部面板

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-inline-preview",
            title: "Inline Preview",
            systemImage: Self.iconName,
            priority: 84
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "editor-bottom-inline-preview",
              activeIcon == EditorPlugin.iconName else {
            return nil
        }
        return AnyView(EditorInlinePreviewDetailView())
    }
}
