import LumiCoreKit
import LumiUI
import SuperLogKit
import Foundation
import LumiPreviewKit
import SwiftUI
import os

/// 预览插件。
///
/// 技术核心为：IOSurface 帧流 + Lumi 面板内 `CALayer` 显示。
/// 通过子进程 `LumiPreviewHostApp` 运行用户编译的预览 dylib，
/// 自动扫描 `#Preview` 宏并构建渲染。
public actor EditorPreviewPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview"
    )

    public nonisolated static let emoji = "IP"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorPreview"
    public static let displayName: String = String(localized: "Inline Preview", table: "EditorPreview")
    public static let description: String = String(localized: "Embedded preview powered by LumiPreviewKit", table: "EditorPreview")
    public static let iconName: String = "rectangle.inset.filled"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 84 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorPreviewPlugin()
    private static let bottomPanelTabId = "editor-bottom-inline-preview"

    // MARK: - 底部面板

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "内嵌预览",
                subtitle: "在编辑器底部构建并显示 SwiftUI、HTML、JSON、PDF 等预览。",
                icon: Self.iconName,
                accent: .purple,
                metrics: [
                    PluginPosterSupport.metric("#Preview", "SwiftUI"),
                    PluginPosterSupport.metric("Files", "多格式"),
                ],
                rows: ["SwiftUI Preview", "HTML/JSON/PDF", "构建状态诊断"],
                chips: ["编辑器", "预览", "底部面板"]
            ),
        ]
    }

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        guard context.isEditorVisible else { return [] }
        return [
            BottomPanelTab(
                id: Self.bottomPanelTabId,
                title: Self.displayName,
                systemImage: Self.iconName,
                priority: Self.order
            ),
        ]
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard context.isEditorVisible, tabId == Self.bottomPanelTabId else { return nil }
        return AnyView(EditorPreviewDetailView())
    }
}
