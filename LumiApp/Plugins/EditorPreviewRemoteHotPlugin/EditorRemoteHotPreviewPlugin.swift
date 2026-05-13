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
    static let displayName: String = "Hot Preview"
    static let description: String = "Experimental hot preview powered by LumiHotPreviewKit"
    static let iconName: String = "bolt.horizontal"
    static var isConfigurable: Bool { false }
    static var order: Int { 83 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorRemoteHotPreviewPlugin()

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-hot-preview",
            title: "Hot Preview",
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
