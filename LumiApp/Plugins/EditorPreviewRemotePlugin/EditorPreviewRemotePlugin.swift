import Foundation
import MagicKit
import SwiftUI
import os

/// Editor bottom panel plugin for the embedded remote preview canvas.
actor EditorPreviewRemotePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-remote-preview")

    nonisolated static let emoji = "RP"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = EditorPreviewRemoteConstants.pluginID
    static let displayName: String = String(localized: "Remote Preview", table: EditorPreviewRemoteConstants.localizationTable)
    static let description: String = String(
        localized: "Embedded remote SwiftUI preview canvas",
        table: EditorPreviewRemoteConstants.localizationTable
    )
    static let iconName: String = "rectangle.inset.filled"
    static var isConfigurable: Bool { false }
    static var order: Int { 82 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorPreviewRemotePlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: EditorPreviewRemoteConstants.bottomTabID,
            title: String(localized: "Remote Preview", table: EditorPreviewRemoteConstants.localizationTable),
            systemImage: "rectangle.inset.filled",
            priority: 82
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == EditorPreviewRemoteConstants.bottomTabID, activeIcon == EditorPlugin.iconName else {
            return nil
        }
        return AnyView(EditorPreviewRemoteDetailView())
    }
}
