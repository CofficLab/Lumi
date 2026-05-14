import Foundation
import MagicKit
import SwiftUI
import os

actor EditorRemoteHotPreviewPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-remote-hot-preview"
    )

    nonisolated static let emoji = "HP"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorRemoteHotPreview"
    static let displayName: String = "预览V2"
    static let description: String = String(localized: "V2 preview powered by LumiHotPreviewKit", table: "EditorPreviewRemoteHotPlugin")
    static let iconName: String = "bolt.horizontal"
    static var isConfigurable: Bool { false }
    static var order: Int { 83 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorRemoteHotPreviewPlugin()

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-hot-preview",
            title: "预览V2",
            systemImage: "bolt.horizontal",
            priority: 83
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "editor-bottom-hot-preview", activeIcon == EditorPlugin.iconName else {
            return nil
        }
        return AnyView(EditorRemoteHotPreviewDetailView())
    }
}
