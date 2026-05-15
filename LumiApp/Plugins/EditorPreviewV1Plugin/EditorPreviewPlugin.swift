import Foundation
import MagicKit
import SwiftUI
import os

/// Editor bottom panel plugin backed by LumiPreviewKit.
actor EditorPreviewPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-preview")

    nonisolated static let emoji = "PV"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    static let id: String = "EditorPreview"
    static let displayName: String = "预览V1"
    static let description: String = String(localized: "V1 preview powered by LumiPreviewKit", table: "EditorPreview")
    static let iconName: String = "rectangle.on.rectangle"
    static var isConfigurable: Bool { false }
    static var order: Int { 81 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorPreviewPlugin()

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-editor-preview",
            title: "预览V1",
            systemImage: "rectangle.on.rectangle",
            priority: 81
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "editor-bottom-editor-preview", activeIcon == EditorPlugin.iconName else {
            return nil
        }
        return AnyView(
            EditorPreviewContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    // Window became active — live preview can show
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    // Window resigned active — live preview should hide
                }
        )
    }
}
